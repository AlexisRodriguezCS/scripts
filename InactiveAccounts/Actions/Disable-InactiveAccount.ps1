function Disable-InactiveAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Raw,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $note = "Disabled: $($Raw.Reason) ($(Get-Date -Format 'yyyy-MM-dd'))"

    # Synced users must be disabled in AD (AD is the source of truth, Entra follows on next sync)
    if ($Raw.Synced) {
        Disable-ADAccount -Identity $Raw.OnPremSam -ErrorAction Stop
        Set-ADUser -Identity $Raw.OnPremSam -Description $note -ErrorAction Stop
        return "Disabled in AD"
    }

    # Cloud-only users are disabled in Entra
    Update-MgUser -UserId $Raw.Id -AccountEnabled:$false -ErrorAction Stop
    return "Disabled in Entra"
}
