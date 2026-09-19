function Invoke-StaleDeviceCleanup {
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

    # 1. Get every Intune device with its last check-in
    $devices = @(Get-DeviceData -LogFile $LogFile)

    foreach ($device in $devices) {
        # 2. Decide: active, excluded, or stale
        Test-StaleDevice -PipelineObject $device -LogFile $LogFile -Config $Config
        # 3. Plan: retire, or delete the record if very old
        New-StaleDevicePlan -PipelineObject $device -LogFile $LogFile -Config $Config
    }

    $toChange = @($devices | Where-Object { $_.Plan.Count -gt 0 })

    # Safety net: a huge share of stale devices usually means sync data is wrong, not that devices are gone
    $maxPercent = if ($Config.MaxPercentToChange) { $Config.MaxPercentToChange } else { 20 }
    $percent    = if ($devices.Count) { [math]::Round(100 * $toChange.Count / $devices.Count, 1) } else { 0 }

    # 4. Execute
    $actions = @{
        Retire       = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Invoke-DeviceRetire -Raw $p.Raw -LogFile $LogFile } }
        DeleteRecord = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) Remove-DeviceRecord -Raw $p.Raw -LogFile $LogFile } }
    }

    if ($Apply -and $percent -gt $maxPercent) {
        Write-Log -Message "SAFETY STOP: $($toChange.Count) of $($devices.Count) devices ($percent%) would change, above the $maxPercent% limit. Nothing changed." `
                  -Level "ERROR" -LogFile $LogFile
        foreach ($device in $toChange) { $device.Errors.Add("Safety stop: $percent% of devices flagged, above $maxPercent% limit"); $device.Status = "Failed" }
    }
    elseif ($Apply) {
        foreach ($device in $toChange) {
            $ok = Invoke-Plan -PipelineObject $device -Actions $actions -LogFile $LogFile
            $device.Status = if (-not $ok) { "Failed" } elseif ($device.Plan[0].Action -eq "Retire") { "Retired" } else { "Deleted" }
        }
    }
    else {
        Write-Log -Message "[DRY RUN] $($toChange.Count) devices would be retired or deleted, nothing changed" -Level "INFO" -LogFile $LogFile
    }

    # 5. Report (only devices with something to do)
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\StaleDevicesReport_$runStamp.txt"
    $null = New-Report -Users $toChange -ReportFile $reportFile
    $toChange | ForEach-Object { $_.Raw } | Select-Object DeviceName, OS, Owner, OwnerType, Serial, LastSync, DaysSinceSync, Compliance |
        Export-Csv -Path "$reportDir\StaleDevices_$runStamp.csv" -NoTypeInformation

    Write-Log -Message "=== Pipeline Finished === Devices: $($devices.Count) | To change: $($toChange.Count) ($percent%) | Duration: $(((Get-Date) - $pipelineStart).TotalSeconds) sec" `
              -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Devices    = $devices.Count
        ToChange   = $toChange.Count
        Retired    = @($devices | Where-Object Status -eq "Retired").Count
        Deleted    = @($devices | Where-Object Status -eq "Deleted").Count
        Failed     = @($devices | Where-Object Status -eq "Failed").Count
        ReportFile = $reportFile
    }
}
