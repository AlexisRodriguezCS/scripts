function Remove-OffboardingDLMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Check if user has a mailbox (no mailbox = no DL memberships)
    $mailbox = Get-Mailbox -Identity $Identity.EntraUPN -ErrorAction SilentlyContinue

    if ($null -eq $mailbox) {
        return "NoMailbox"
    }

    # Cloud DLs the user is in. Synced (AD) groups are already handled by RemoveFromGroup.
    $lists = @(Get-Recipient -Filter "Members -eq '$($mailbox.DistinguishedName)'" `
                             -RecipientTypeDetails MailUniversalDistributionGroup, MailUniversalSecurityGroup `
                             -ResultSize Unlimited -ErrorAction Stop |
               Where-Object { -not $_.IsDirSynced })

    if ($lists.Count -eq 0) {
        return "NoDistributionLists"
    }

    foreach ($list in $lists) {
        Remove-DistributionGroupMember -Identity $list.Identity -Member $Identity.EntraUPN `
            -BypassSecurityGroupManagerCheck -Confirm:$false -ErrorAction Stop
        Write-Log -Message "[$($Identity.SamAccountName)] Removed from DL: $($list.Name)" -Level "INFO" -LogFile $LogFile
    }

    return "Removed from $($lists.Count) list(s)"
}
