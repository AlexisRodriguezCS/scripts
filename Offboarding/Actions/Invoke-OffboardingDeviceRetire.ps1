function Invoke-OffboardingDeviceRetire {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Every Intune device the leaver uses (company laptops and personal phones)
    $devices = @(Get-MgUserManagedDevice -UserId $Identity.EntraUPN -All `
                    -Property "id,deviceName,operatingSystem,managedDeviceOwnerType,managementState" -ErrorAction Stop)

    if ($devices.Count -eq 0) {
        return "NoDevices"
    }

    # Retire = remove company data, apps and email profiles; personal photos etc. are untouched.
    # Devices already retiring (from a previous run) are skipped.
    $retired = @()
    foreach ($device in $devices | Where-Object { "$($_.ManagementState)" -ne "retirePending" }) {
        Invoke-MgRetireDeviceManagementManagedDevice -ManagedDeviceId $device.Id -ErrorAction Stop
        $retired += "$($device.DeviceName) ($($device.OperatingSystem), $($device.ManagedDeviceOwnerType))"
        Write-Log -Message "[$($Identity.SamAccountName)] Retire sent: $($retired[-1])" -Level "INFO" -LogFile $LogFile
    }

    if ($retired.Count -eq 0) {
        return "Retire already pending on $($devices.Count) device(s)"
    }
    return "Retire sent to $($retired.Count) device(s): $($retired -join ', ')"
}
