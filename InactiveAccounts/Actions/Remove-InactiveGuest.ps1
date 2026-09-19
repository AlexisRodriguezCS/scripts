function Remove-InactiveGuest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Raw,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Goes to the Entra recycle bin; can be restored for 30 days
    Remove-MgUser -UserId $Raw.Id -ErrorAction Stop
    return "Removed (restorable for 30 days)"
}
