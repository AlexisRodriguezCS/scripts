function Invoke-RestoreFromSnapshot {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SnapshotFile,
        [Parameter(Mandatory)]
        [string]$LogFile,
        [bool]$Apply
    )

    $runStamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir = "$PSScriptRoot\..\..\Reports"

    # 1. Compare the snapshot with today and plan only the difference
    $user = New-RestorePlan -SnapshotFile $SnapshotFile -LogFile $LogFile

    foreach ($item in $user.Plan) {
        $detail = if ($item.Action -eq "SetAttribute") { "$($item.Target): '$($item.Old)' -> '$($item.Value)'" } else { $item.Target }
        Write-Log -Message "[$($user.Raw.SamAccountName)] [Restore] $($item.Action) -> $detail : PENDING" -Level "INFO" -LogFile $LogFile
    }

    # 2. Execute
    if ($Apply -and $user.Status -eq "Valid") {
        $actions = @{
            EnableAccount   = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Enable-ADAccount -Identity $p.Identity.DistinguishedName -ErrorAction Stop; "Enabled" } }
            SetAttribute    = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t, $item) Set-UserAttribute -Identity $p.Identity -Attribute $t -Value $item.Value -LogFile $LogFile } }
            AddToGroup      = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Add-ADGroupMember -Identity $t -Members $p.Identity.DistinguishedName -ErrorAction Stop; "Added back" } }
            RemoveFromGroup = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Remove-OffboardingGroupMember -Identity $p.Identity -Target $t -LogFile $LogFile } }
            MoveToOU        = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Move-OffboardingUser -Identity $p.Identity -Target $t -LogFile $LogFile } }
        }

        $ok = Invoke-Plan -PipelineObject $user -Actions $actions -LogFile $LogFile
        $user.Status = if ($ok) { "Restored" } else { "Failed" }
    }

    # 3. Report
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\RestoreReport_$runStamp.txt"
    $null = New-Report -Users @($user) -ReportFile $reportFile
    if ($user.Manual) {
        @("", "=== DO BY HAND ===") + ($user.Manual | ForEach-Object { "- $_" }) | Out-File -FilePath $reportFile -Append -Encoding utf8
    }

    return [pscustomobject]@{
        SamAccountName = $user.Raw.SamAccountName
        SnapshotTaken  = $user.Raw.TakenAt
        Status         = $user.Status
        Plan           = @($user.Plan | ForEach-Object { "$($_.Action) -> $($_.Target) : $($_.Result)" })
        DoByHand       = $user.Manual
        ReportFile     = $reportFile
    }
}
