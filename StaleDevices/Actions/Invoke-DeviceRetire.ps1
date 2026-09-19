function Invoke-DeviceRetire {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Raw,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Retire = remove company data, apps and email profiles; personal data is untouched.
    # Runs the next time the device checks in.
    Invoke-MgRetireDeviceManagementManagedDevice -ManagedDeviceId $Raw.Id -ErrorAction Stop
    return "Retire sent"
}
