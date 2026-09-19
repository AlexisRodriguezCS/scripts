function Sync-MoverDLMembership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        # Semicolon-separated DLs the user should be in (may be empty)
        [AllowEmptyString()]
        [string]$Target,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Check if user has a mailbox (no mailbox = no DL memberships)
    $mailbox = Get-Mailbox -Identity $Identity.EntraUPN -ErrorAction SilentlyContinue
    if ($null -eq $mailbox) {
        return "NoMailbox"
    }

    # Only department/role DLs are managed; the all-staff list is never touched
    $managed = @($Config.DistributionLists | Where-Object { $_ -ne $Config.DefaultDistributionList })
    $desired = @($Target -split ';' | Where-Object { $_ })

    $current = @(Get-Recipient -Filter "Members -eq '$($mailbox.DistinguishedName)'" `
                               -RecipientTypeDetails MailUniversalDistributionGroup, MailUniversalSecurityGroup `
                               -ResultSize Unlimited -ErrorAction Stop | ForEach-Object { $_.Name })

    $added   = @($desired | Where-Object { $_ -notin $current })
    $removed = @($current | Where-Object { $_ -in $managed -and $_ -notin $desired })

    foreach ($list in $added) {
        Add-DistributionGroupMember -Identity $list -Member $Identity.EntraUPN -ErrorAction Stop
    }
    foreach ($list in $removed) {
        Remove-DistributionGroupMember -Identity $list -Member $Identity.EntraUPN -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
    }

    if ($added.Count -eq 0 -and $removed.Count -eq 0) {
        return "No change"
    }
    return "Added: $($added -join ', ') | Removed: $($removed -join ', ')"
}
