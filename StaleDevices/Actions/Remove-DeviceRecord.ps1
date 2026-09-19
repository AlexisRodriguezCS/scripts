function Remove-DeviceRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Raw,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Removes the Intune record only; if the device ever comes back it simply re-enrolls
    Remove-MgDeviceManagementManagedDevice -ManagedDeviceId $Raw.Id -ErrorAction Stop
    return "Record deleted"
}
