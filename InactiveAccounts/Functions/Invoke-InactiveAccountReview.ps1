function Invoke-InactiveAccountReview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogFile,
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [bool]$Apply
    )

    $pipelineStart = Get-Date
    $runStamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir     = "$PSScriptRoot\..\..\Reports"

    # 1. Get every enabled account with its last sign-in
    $users = @(Get-InactiveAccountData -LogFile $LogFile)

    # Safety net: if a huge share of the tenant looks inactive, something is wrong (e.g. sign-in data missing)
    $maxPercent = if ($Config.MaxPercentToDisable) { $Config.MaxPercentToDisable } else { 10 }

    # Admin role holders, read once: they are reported, never disabled automatically
    $adminIds = Get-AdminAccountId -LogFile $LogFile

    foreach ($user in $users) {
        # 2. Decide: active, excluded, inactive, or an admin for a human to review
        Test-InactiveAccount -PipelineObject $user -LogFile $LogFile -Config $Config -AdminIds $adminIds
        # 3. Plan: disable members, remove guests
        New-InactiveAccountPlan -PipelineObject $user -LogFile $LogFile
    }

    $inactive = @($users | Where-Object Status -eq "Inactive")
    $percent  = if ($users.Count) { [math]::Round(100 * $inactive.Count / $users.Count, 1) } else { 0 }

    # 4. Execute
    if ($Apply -and $percent -gt $maxPercent) {
        Write-Log -Message "SAFETY STOP: $($inactive.Count) of $($users.Count) accounts ($percent%) look inactive, above the $maxPercent% limit. Nothing changed." `
                  -Level "ERROR" -LogFile $LogFile
        foreach ($user in $inactive) { $user.Errors.Add("Safety stop: $percent% of accounts flagged, above $maxPercent% limit") ; $user.Status = "Failed" }
    }
    elseif ($Apply) {
        foreach ($user in $inactive) {
            $null = Start-InactiveAccountCleanup -PipelineObject $user -LogFile $LogFile -SnapshotFolder "$reportDir\Snapshots\InactiveAccounts_$runStamp"
        }
    }
    else {
        Write-Log -Message "[DRY RUN] $($inactive.Count) inactive accounts found, nothing changed" -Level "INFO" -LogFile $LogFile
    }

    # 5. Report (only accounts that were inactive; active ones would bury the list)
    $reported = @($users | Where-Object Status -notin @("Active", "Excluded"))

    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\InactiveAccountsReport_$runStamp.txt"
    $null = New-Report -Users $reported -ReportFile $reportFile
    $reported | ForEach-Object { $_.Raw } | Select-Object UPN, DisplayName, UserType, Synced, LastSignIn, DaysInactive, Reason |
        Export-Csv -Path "$reportDir\InactiveAccounts_$runStamp.csv" -NoTypeInformation

    Write-Log -Message "=== Pipeline Finished === Checked: $($users.Count) | Inactive: $($inactive.Count) ($percent%) | Duration: $(((Get-Date) - $pipelineStart).TotalSeconds) sec" `
              -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Checked     = $users.Count
        Inactive    = $inactive.Count
        AdminReview = @($users | Where-Object Status -eq "AdminReview").Count
        Disabled    = @($users | Where-Object Status -eq "Disabled").Count
        Removed     = @($users | Where-Object Status -eq "Removed").Count
        Failed      = @($users | Where-Object Status -eq "Failed").Count
        ReportFile  = $reportFile
    }
}
