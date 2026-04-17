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

    # Ensure UsageLocation is set first
    try {
        Update-MgUser -UserId $Identity.EntraUPN `
            -UsageLocation $Config.UsageLocation `
            -ErrorAction Stop
    }
    catch {
        throw "Failed to set UsageLocation: $($_.Exception.Message)"
    }

    # Assign license
    try {
        $null = Set-MgUserLicense -UserId $Identity.EntraUPN `
            -AddLicenses @{ SkuId = $Config.LicenseSkuId } `
            -RemoveLicenses @() `
            -ErrorAction Stop
    }
    catch {
        throw "License assignment failed: $($_.Exception.Message)"
    }

    return "Added"
}