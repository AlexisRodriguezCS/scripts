function Disable-IncidentAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Synced users: AD is the source; disabling only in Entra would be undone at the next sync.
    # Disable in Entra too so it takes effect now instead of after the sync.
    if ($Identity.Synced) {
        Disable-ADAccount -Identity $Identity.SamAccountName -ErrorAction Stop
        Set-ADUser -Identity $Identity.SamAccountName -Description "Disabled: suspected compromise $(Get-Date -Format 'yyyy-MM-dd HH:mm')" -ErrorAction Stop
    }

    # Cloud-only users can be disabled directly; for synced users this may be refused (sync owns it), AD already did it
    try {
        Update-MgUser -UserId $Identity.Id -AccountEnabled:$false -ErrorAction Stop
    }
    catch {
        if (-not $Identity.Synced) { throw }
    }

    return $(if ($Identity.Synced) { "Disabled in AD" } else { "Disabled in Entra" })
}
