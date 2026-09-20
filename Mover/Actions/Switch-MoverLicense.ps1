function Switch-MoverLicense {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        # SkuId the new role should have
        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $user = Get-MgUser -UserId $Identity.EntraUPN -Property "assignedLicenses,usageLocation" -ErrorAction Stop
    $assigned = @($user.AssignedLicenses | ForEach-Object { "$($_.SkuId)" })

    if ($Target -in $assigned) { return "AlreadyAssigned" }

    # Only licenses listed in RoleLicenseSkuIds are managed here. Anything else the user holds
    # (Visio, Project, a phone system add-on bought separately) is left alone.
    $managed = @($Config.RoleLicenseSkuIds.PSObject.Properties.Value | Where-Object { $_ })
    $remove  = @($assigned | Where-Object { $_ -in $managed -and $_ -ne $Target })

    # A license can't be assigned without a usage location, and older accounts may not have one
    if (-not $user.UsageLocation -and $Config.UsageLocation) {
        Update-MgUser -UserId $Identity.EntraUPN -UsageLocation $Config.UsageLocation -ErrorAction Stop
    }

    # Add and remove in one call: Microsoft 365 keeps the mailbox as long as a license
    # is assigned at every moment, and a gap can start a 30-day deletion timer
    $null = Set-MgUserLicense -UserId $Identity.EntraUPN `
                              -AddLicenses @(@{ SkuId = $Target }) `
                              -RemoveLicenses @($remove) `
                              -ErrorAction Stop

    Write-Log -Message "[$($Identity.SamAccountName)] [Switch-MoverLicense] Added $Target, removed $($remove -join ', ')" `
              -Level "INFO" -LogFile $LogFile

    return $(if ($remove.Count) { "Swapped to the new role's license" } else { "Added the new role's license" })
}
