function Invoke-IncidentResponse {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$UserPrincipalName,
        [Parameter(Mandatory)]
        [string]$LogFile,
        [int]$SignInDays = 7,
        [bool]$Apply
    )

    $runStamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir = "$PSScriptRoot\..\..\Reports"
    # Evidence is kept (not under Reports/, so the 90-day cleanup doesn't delete it)
    $folder    = "$PSScriptRoot\..\..\Backups\Incidents\$($UserPrincipalName -replace '[^\w\.-]', '_')_$runStamp"

    # 1. Who
    $user = Get-IncidentIdentity -UserPrincipalName $UserPrincipalName -LogFile $LogFile
    # 2. Evidence first, always (dry run too)
    Save-IncidentEvidence -PipelineObject $user -Folder $folder -SignInDays $SignInDays -LogFile $LogFile
    # 3. Plan containment
    New-IncidentPlan -PipelineObject $user -LogFile $LogFile

    # 4. Contain
    if ($Apply) {
        $actions = @{
            DisableAccount   = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Disable-IncidentAccount -Identity $p.Identity -LogFile $LogFile } }
            ResetPassword    = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Reset-IncidentPassword -Identity $p.Identity -LogFile $LogFile } }
            RevokeSessions   = @{ MaxRetries = 4; DelaySeconds = 5; Run = { param($p, $t) Revoke-OffboardingSession -Identity $p.Identity -LogFile $LogFile } }
            RemoveForwarding = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Remove-IncidentForwarding -Identity $p.Identity -LogFile $LogFile } }
            DisableInboxRule = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t, $item) Disable-IncidentInboxRule -Identity $p.Identity -RuleIdentity $item.RuleIdentity -LogFile $LogFile } }
        }

        $null = Save-UserSnapshot -PipelineObject $user -Stage Before -Folder $folder -LogFile $LogFile
        # Keep going even if one step fails: a partly contained account is better than an open one
        $ok = Invoke-Plan -PipelineObject $user -Actions $actions -LogFile $LogFile
        $null = Save-UserSnapshot -PipelineObject $user -Stage After -Folder $folder -LogFile $LogFile

        $user.Status = if ($ok) { "Contained" } else { "Failed" }
    }
    else {
        Write-Log -Message "[DRY RUN] Evidence collected, nothing changed. Run with -Apply to contain." -Level "WARN" -LogFile $LogFile
    }

    # 5. Things only a human can judge
    $review = @()
    if ($user.Evidence.NewMethods.Count) { $review += "$($user.Evidence.NewMethods.Count) MFA method(s) added in the last $SignInDays days: check they're really the user's (mfa-methods.json)" }
    if ($user.Evidence.Countries.Count -gt 1) { $review += "Sign-ins from $($user.Evidence.Countries.Count) countries: $($user.Evidence.Countries -join ', ') (sign-ins.csv)" }
    $review += "Check sent items and any files shared in the last $SignInDays days"
    $review += "Give the user a new password (or Temporary Access Pass) once you're sure the attacker is out"

    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\IncidentReport_$runStamp.txt"
    $null = New-Report -Users @($user) -ReportFile $reportFile
    @("", "=== FOLLOW UP ===") + ($review | ForEach-Object { "- $_" }) + @("", "Evidence: $folder") |
        Out-File -FilePath $reportFile -Append -Encoding utf8

    return [pscustomobject]@{
        User       = $UserPrincipalName
        Status     = $user.Status
        Plan       = @($user.Plan | ForEach-Object { "$($_.Action) -> $($_.Target) : $($_.Result)" })
        FollowUp   = $review
        Evidence   = $folder
        ReportFile = $reportFile
    }
}
