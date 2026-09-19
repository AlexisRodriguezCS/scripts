function Hide-OffboardingFromAddressBook {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Hybrid: the address book setting is an AD attribute that syncs to Exchange Online
    # (Exchange Online can't change it for synced users). Needs the Exchange schema in AD,
    # which every hybrid Exchange setup has.
    $user = Get-ADUser -Identity $Identity.DistinguishedName -Properties msExchHideFromAddressLists -ErrorAction Stop

    if ($user.msExchHideFromAddressLists -eq $true) {
        return "AlreadyHidden"
    }

    try {
        Set-ADUser -Identity $Identity.DistinguishedName -Replace @{ msExchHideFromAddressLists = $true } -ErrorAction Stop
    }
    catch {
        if ($_.Exception.Message -match "attribute") {
            throw "AD has no msExchHideFromAddressLists attribute (Exchange schema not extended); hide the mailbox by hand"
        }
        throw
    }

    return "Hidden"
}
