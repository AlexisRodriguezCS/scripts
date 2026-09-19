function Remove-OffboardingLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Get currently assigned licenses
    $user = Get-MgUser -UserId $Identity.EntraUPN `
                       -Property "assignedLicenses" `
                       -ErrorAction Stop

    $skuIds = @($user.AssignedLicenses.SkuId | Where-Object { $_ })

    if ($skuIds.Count -eq 0) {
        return "NoLicenses"
    }

    # Remove all licenses
    try {
        $null = Set-MgUserLicense -UserId $Identity.EntraUPN `
            -AddLicenses @() `
            -RemoveLicenses $skuIds `
            -ErrorAction Stop
    }
    catch {
        throw "License removal failed: $($_.Exception.Message)"
    }

    return "Licenses removed"
}
