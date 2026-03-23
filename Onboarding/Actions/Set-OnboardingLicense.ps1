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
        Write-Log -Message "`tAssignLicense          : License already assigned, skipping" -Level "INFO" -LogFile $LogFile
        return
    }

    # Assign license
    Set-MgUserLicense -UserId $Identity.EntraUPN `
                      -AddLicenses @{ SkuId = $Config.LicenseSkuId } `
                      -RemoveLicenses @()

    Write-Log -Message "`tAssignLicense          : Assigned license to $($Identity.DisplayName)" -Level "INFO" -LogFile $LogFile
}