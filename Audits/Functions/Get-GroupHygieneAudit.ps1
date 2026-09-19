function Get-GroupHygieneAudit {
    [CmdletBinding()]
    param(
        [string]$LogFile,
        # Injectable for tests
        [datetime]$Now = (Get-Date)
    )

    # Cloud groups only: groups synced from AD are owned and cleaned up in AD
    $groups = @(Get-MgGroup -All -Property "id,displayName,groupTypes,mailEnabled,securityEnabled,onPremisesSyncEnabled,createdDateTime,resourceProvisioningOptions" -ErrorAction Stop |
                Where-Object { -not $_.OnPremisesSyncEnabled })

    # ponytail: two calls per group; fine for hundreds of groups, switch to Graph batching for thousands
    foreach ($group in $groups) {
        $kind = if ($group.ResourceProvisioningOptions -contains "Team") { "Team" }
                elseif ($group.GroupTypes -contains "Unified") { "Microsoft 365 group" }
                elseif ($group.MailEnabled -and -not $group.SecurityEnabled) { "Distribution list" }
                elseif ($group.MailEnabled) { "Mail-enabled security group" }
                else { "Security group" }

        $owners  = @(Get-MgGroupOwner -GroupId $group.Id -All -ErrorAction SilentlyContinue)
        $members = @(Get-MgGroupMember -GroupId $group.Id -All -ErrorAction SilentlyContinue)
        $ageDays = [int]($Now - [datetime]$group.CreatedDateTime).TotalDays

        $reasons = @()
        if ($owners.Count -eq 0)  { $reasons += "No owner: nobody to approve access or clean it up" }
        # Brand new groups are allowed to be empty for a while
        if ($members.Count -eq 0 -and $ageDays -gt 30) { $reasons += "Empty for $ageDays days: probably safe to delete" }

        New-AuditFinding -Check "Groups" -Name $group.DisplayName `
                         -Detail "$kind | Owners: $($owners.Count) | Members: $($members.Count)" `
                         -Flagged ($reasons.Count -gt 0) -Reason ($reasons -join "; ")
    }
}
