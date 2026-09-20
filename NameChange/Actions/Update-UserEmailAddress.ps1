function Update-UserEmailAddress {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        # New primary address
        [Parameter(Mandatory)]
        [string]$Target,

        # Keep the old address as an alias so mail sent to it still arrives
        [bool]$KeepOld = $true,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # In a hybrid tenant, Exchange Online reads these from AD, so the addresses are set here
    # and reach Microsoft 365 on the next sync. SMTP: (capital) is the primary, smtp: an alias.
    $existing = @($Identity.Current.proxyAddresses)
    $addresses = [System.Collections.Generic.List[string]]::new()

    foreach ($address in $existing) {
        if ("$address" -like "SMTP:*") {
            # The old primary becomes an alias, or is dropped if the request said not to keep it
            if ($KeepOld) { $addresses.Add("smtp:$("$address" -replace '^SMTP:')") }
        }
        elseif ("$address") {
            $addresses.Add("$address")
        }
    }

    # Nothing to do if it is already the primary (safe to re-run)
    if ($existing -contains "SMTP:$Target") { return "AlreadyPrimary" }

    # Same address lower down the list would collide with the new primary
    $addresses = @($addresses | Where-Object { $_ -ne "smtp:$Target" })
    $addresses = @("SMTP:$Target") + $addresses

    Set-ADUser -Identity $Identity.DistinguishedName -Replace @{ proxyAddresses = $addresses } -ErrorAction Stop
    Set-ADUser -Identity $Identity.DistinguishedName -EmailAddress $Target -ErrorAction Stop

    $previous = "$(@($existing | Where-Object { $_ -clike 'SMTP:*' } | Select-Object -First 1) -replace '^SMTP:')"
    $kept     = if ($KeepOld) { "kept as an alias" } else { "removed" }

    if ($previous) { return "$previous is now $Target ($previous $kept)" }

    # On-prem clients often have no address at all, which is worth saying plainly
    return "Set to $Target (had no address before)"
}
