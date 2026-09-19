function Get-AdminRoleAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [string]$LogFile
    )

    # Microsoft recommends fewer than 5 Global Admins
    $maxGlobalAdmins = if ($Config.MaxGlobalAdmins) { $Config.MaxGlobalAdmins } else { 4 }

    # Only roles with at least one active member show up here
    $roles = Get-MgDirectoryRole -All -ErrorAction Stop

    foreach ($role in $roles) {
        $members = @(Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All -ErrorAction Stop)

        if ($role.DisplayName -eq "Global Administrator" -and $members.Count -gt $maxGlobalAdmins) {
            New-AuditFinding -Check "AdminRoles" -Name "Global Administrator" -Detail "$($members.Count) members" `
                             -Flagged $true -Reason "More than $maxGlobalAdmins Global Admins"
        }

        foreach ($member in $members) {
            $upn  = $member.AdditionalProperties.userPrincipalName
            $name = if ($upn) { $upn } else { $member.AdditionalProperties.displayName }

            # Guests (external accounts) should never hold directory roles
            $isGuest = $upn -like "*#EXT#*"

            New-AuditFinding -Check "AdminRoles" -Name $name -Detail $role.DisplayName `
                             -Flagged $isGuest -Reason $(if ($isGuest) { "Guest account holds an admin role" })
        }
    }
}
