function Get-PrivilegedAccessAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [string]$LogFile
    )

    # Roles that can take over the tenant or its data if abused
    $privilegedRoles = @(
        "Global Administrator", "Privileged Role Administrator", "Privileged Authentication Administrator",
        "Security Administrator", "Conditional Access Administrator", "Exchange Administrator",
        "SharePoint Administrator", "User Administrator", "Application Administrator",
        "Cloud Application Administrator", "Intune Administrator", "Hybrid Identity Administrator"
    )

    $roleNames = @{}
    foreach ($role in Get-MgRoleManagementDirectoryRoleDefinition -All -ErrorAction Stop) { $roleNames[$role.Id] = $role.DisplayName }

    # Active assignments. AssignmentType "Assigned" = standing access; "Activated" = turned on through PIM for a limited time
    $active   = @(Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance -All -ExpandProperty "principal" -ErrorAction Stop)
    # Eligible = can activate through PIM when needed (the good state)
    $eligible = @(Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance -All -ExpandProperty "principal" -ErrorAction SilentlyContinue)

    function Get-PrincipalName($instance) {
        $p = $instance.Principal.AdditionalProperties
        if ($p.userPrincipalName) { $p.userPrincipalName } elseif ($p.displayName) { $p.displayName } else { $instance.PrincipalId }
    }

    foreach ($instance in $active) {
        $role = $roleNames[$instance.RoleDefinitionId]
        if ($role -notin $privilegedRoles) { continue }

        $name      = Get-PrincipalName $instance
        $permanent = $instance.AssignmentType -eq "Assigned" -and -not $instance.EndDateTime
        # Break-glass accounts are meant to be permanent (they're the way back in if PIM or MFA breaks)
        $breakGlass = $Config.BreakGlassAccounts -and $name -in $Config.BreakGlassAccounts

        $reason = if ($permanent -and -not $breakGlass) { "Permanent ${role}: make it PIM-eligible so it's only active when needed" }

        New-AuditFinding -Check "PrivilegedAccess" -Name $name `
                         -Detail "$role | $(if ($permanent) { 'permanent' } elseif ($instance.AssignmentType -eq 'Activated') { "activated via PIM until $($instance.EndDateTime)" } else { "time-bound until $($instance.EndDateTime)" })$(if ($breakGlass) { ' | break-glass' })" `
                         -Flagged ([bool]$reason) -Reason $reason
    }

    foreach ($instance in $eligible) {
        $role = $roleNames[$instance.RoleDefinitionId]
        if ($role -notin $privilegedRoles) { continue }
        New-AuditFinding -Check "PrivilegedAccess" -Name (Get-PrincipalName $instance) -Detail "$role | eligible (PIM)"
    }
}
