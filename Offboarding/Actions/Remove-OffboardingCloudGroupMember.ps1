function Remove-OffboardingCloudGroupMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        # Manager's UPN (optional): takes over as owner where the leaver was the only owner
        [string]$Manager,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $user = Get-MgUser -UserId $Identity.EntraUPN -Property "id" -ErrorAction Stop

    # Cloud groups Graph can change: Teams / Microsoft 365 groups and plain security groups.
    # Skipped: synced groups (AD, handled by RemoveFromGroup), dynamic groups (rules decide membership),
    # mail-enabled security groups and DLs (Exchange, handled by RemoveFromDistributionLists).
    $groups = @(Get-MgUserMemberOf -UserId $user.Id -All -ErrorAction Stop | Where-Object {
        $g = $_.AdditionalProperties
        $g.'@odata.type' -eq "#microsoft.graph.group" -and
        -not $g.onPremisesSyncEnabled -and
        $g.groupTypes -notcontains "DynamicMembership" -and
        ($g.groupTypes -contains "Unified" -or ($g.securityEnabled -and -not $g.mailEnabled))
    })

    if ($groups.Count -eq 0) {
        return "NoCloudGroups"
    }

    $managerId = if ($Manager) { (Get-MgUser -UserId $Manager -Property "id" -ErrorAction Stop).Id }
    $removed   = @()
    $orphaned  = @()

    foreach ($group in $groups) {
        $name   = $group.AdditionalProperties.displayName
        $owners = @(Get-MgGroupOwner -GroupId $group.Id -All -ErrorAction Stop)

        if ($owners.Id -contains $user.Id) {
            # Never leave a team without an owner: hand it to the manager first
            if ($owners.Count -eq 1) {
                if ($managerId) {
                    New-MgGroupOwnerByRef -GroupId $group.Id -BodyParameter @{ "@odata.id" = "https://graph.microsoft.com/v1.0/directoryObjects/$managerId" } -ErrorAction Stop
                    Write-Log -Message "[$($Identity.SamAccountName)] $Manager is now owner of $name" -Level "INFO" -LogFile $LogFile
                } else {
                    $orphaned += $name
                }
            }
            Remove-MgGroupOwnerByRef -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
        }

        Remove-MgGroupMemberByRef -GroupId $group.Id -DirectoryObjectId $user.Id -ErrorAction Stop
        $removed += $name
        Write-Log -Message "[$($Identity.SamAccountName)] Removed from cloud group: $name" -Level "INFO" -LogFile $LogFile
    }

    $result = "Removed from $($removed.Count) Teams/cloud group(s): $($removed -join ', ')"
    if ($orphaned) {
        # Done, but a human needs to pick a new owner
        $result += ". NO OWNER LEFT (no manager given): $($orphaned -join ', ')"
    }
    return $result
}
