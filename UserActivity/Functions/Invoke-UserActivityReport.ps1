function Invoke-UserActivityReport {
    [CmdletBinding()]
    param(
        # Cloud / hybrid clients
        [string]$UserPrincipalName,

        # On-prem only clients (no Entra): AD sources only
        [string]$SamAccountName,
        [switch]$OnPremOnly,

        [ValidateRange(1, 30)]
        [int]$Days = 14,

        [string]$LockoutServer,

        [string]$LogFile
    )

    $since     = (Get-Date).AddDays(-$Days)
    $runStamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir = "$PSScriptRoot\..\..\Reports"

    if ($OnPremOnly) {
        $adUser = Get-ADUser -Identity $SamAccountName -Properties DisplayName -ErrorAction Stop
        $user = [pscustomobject]@{ Id = $null; DisplayName = $adUser.DisplayName; UserPrincipalName = $SamAccountName
                                   OnPremisesSyncEnabled = $true; OnPremisesSamAccountName = $SamAccountName }
    } else {
        $user = Get-MgUser -UserId $UserPrincipalName -Property "id,displayName,userPrincipalName,onPremisesSyncEnabled,onPremisesSamAccountName" -ErrorAction Stop
    }
    $UserPrincipalName = $user.UserPrincipalName

    # Each source on its own: one missing permission or license shouldn't hide the rest
    $events = [System.Collections.Generic.List[object]]::new()
    $state  = $null

    if (-not $OnPremOnly) {
        $sources = [ordered]@{
            "Sign-ins"     = @{ Read = { Get-SignInEvents -UserId $user.Id -Since $since }; Hint = "sign-in logs need Entra ID P1 and AuditLog.Read.All" }
            "Entra audit"  = @{ Read = { Get-AuditEvents -UserId $user.Id -Since $since };  Hint = "needs AuditLog.Read.All" }
        }
        foreach ($name in $sources.Keys) {
            try { foreach ($e in & $sources[$name].Read) { $events.Add($e) } }
            catch { $events.Add((New-ActivityEvent -Time (Get-Date) -Source $name -Event "Couldn't read $name ($($sources[$name].Hint))" -Detail $_.Exception.Message)) }
        }
    }

    # AD only exists for synced users
    if ($user.OnPremisesSyncEnabled -and $user.OnPremisesSamAccountName) {
        try {
            $ad = Get-AdAccountEvents -SamAccountName $user.OnPremisesSamAccountName -Since $since -LockoutServer $LockoutServer
            $state = $ad.State
            foreach ($e in $ad.Events) { $events.Add($e) }
        }
        catch { $events.Add((New-ActivityEvent -Time (Get-Date) -Source "AD" -Event "Couldn't read AD" -Detail $_.Exception.Message)) }
    }

    $timeline = @($events | Sort-Object Time -Descending)
    $summary  = @(Get-ActivitySummary -Events $timeline -State $state -Days $Days)

    # Report: summary first, then the timeline
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $safeName   = $UserPrincipalName -replace '[^\w\.-]', '_'
    $reportFile = "$reportDir\UserActivity_$($safeName)_$runStamp.txt"
    $csvFile    = "$reportDir\UserActivity_$($safeName)_$runStamp.csv"

    $lines  = @("=== User activity: $($user.DisplayName) ($UserPrincipalName), last $Days days ===", "")
    $lines += "=== SUMMARY ==="
    $lines += $summary | ForEach-Object { "- $_" }
    $lines += "", "=== TIMELINE (newest first) ==="
    $lines += $timeline | ForEach-Object { "{0:yyyy-MM-dd HH:mm} | {1,-11} | {2,-7} | {3} | {4}" -f $_.Time, $_.Source, $_.Result, $_.Event, $_.Detail }
    $lines += "", "Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines | Out-File -FilePath $reportFile -Encoding utf8
    $timeline | Export-Csv -Path $csvFile -NoTypeInformation

    if ($LogFile) { Write-Log -Message "[UserActivity] $UserPrincipalName : $($timeline.Count) events, report $reportFile" -Level "INFO" -LogFile $LogFile }

    return [pscustomobject]@{
        User       = $UserPrincipalName
        Summary    = $summary
        Events     = $timeline.Count
        ReportFile = $reportFile
        CsvFile    = $csvFile
    }
}
