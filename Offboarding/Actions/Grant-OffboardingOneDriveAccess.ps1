function Grant-OffboardingOneDriveAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Find the user's OneDrive site
    $oneDriveUrl = (Get-PnPUserProfileProperty -Account $Identity.EntraUPN -ErrorAction Stop).PersonalUrl

    if (-not $oneDriveUrl) {
        return "NoOneDrive"
    }

    # Make the manager a site collection admin (same as "Access files" in the M365 admin center)
    Set-PnPTenantSite -Identity $oneDriveUrl -Owners $Target -ErrorAction Stop

    return "Granted"
}
