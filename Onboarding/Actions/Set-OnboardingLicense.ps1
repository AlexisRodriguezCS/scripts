function Set-OnboardingLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Check if license already assigned
    $user = Get-MgUser -UserId $Identity.EntraUPN `
                       -Property "assignedLicenses" `
                       -ErrorAction Stop

    $alreadyAssigned = $user.AssignedLicenses | Where-Object { $_.SkuId -eq $Config.LicenseSkuId }

    if ($alreadyAssigned) {
        return "AlreadyAssigned" 
    }

    Update-MgUser -UserId $Identity.EntraUPN -UsageLocation $Config.UsageLocation

    # Assign license
    Set-MgUserLicense -UserId $Identity.EntraUPN `
                      -AddLicenses @{ SkuId = $Config.LicenseSkuId } `
                      -RemoveLicenses @()

    return "Added"
}