function Get-DeviceData {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    Write-Log -Message "[Get-DeviceData] Fetching Intune managed devices" -Level "DEBUG" -LogFile $LogFile

    $devices = Get-MgDeviceManagementManagedDevice -All `
        -Property "id,deviceName,operatingSystem,userPrincipalName,lastSyncDateTime,complianceState,managedDeviceOwnerType,managementState,serialNumber" `
        -ErrorAction Stop

    # Build pipeline objects
    $pipelineObjects = foreach ($device in $devices) {
        [pscustomobject]@{
            CorrelationId = [guid]::NewGuid().ToString()
            Raw    = [pscustomobject]@{
                SamAccountName  = $device.DeviceName        # Name shown in reports
                Id              = $device.Id
                DeviceName      = $device.DeviceName
                OS              = $device.OperatingSystem
                Owner           = $device.UserPrincipalName
                OwnerType       = "$($device.ManagedDeviceOwnerType)"   # company | personal
                LastSync        = $device.LastSyncDateTime
                Compliance      = "$($device.ComplianceState)"
                ManagementState = "$($device.ManagementState)"          # retirePending once a retire was sent
                Serial          = $device.SerialNumber
                DaysSinceSync   = $null
            }
            Errors = [System.Collections.Generic.List[object]]::new()
            Plan   = @()
            Identity = $null
            Status  = "Pending"   # Active | Excluded | Stale | Retired | Deleted | Failed
            StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
            StepDurations  = @{}
        }
    }

    Write-Log -Message "[Get-DeviceData] Fetched $(@($pipelineObjects).Count) devices" -Level "INFO" -LogFile $LogFile

    return $pipelineObjects
}
