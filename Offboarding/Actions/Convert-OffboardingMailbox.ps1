function Convert-OffboardingMailbox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Check if user has a mailbox
    $mailbox = Get-Mailbox -Identity $Identity.EntraUPN -ErrorAction SilentlyContinue

    if ($null -eq $mailbox) {
        return "NoMailbox"
    }

    if ($mailbox.RecipientTypeDetails -eq "SharedMailbox") {
        return "AlreadyShared"
    }

    # Shared mailboxes don't need a license, so the data survives license removal
    Set-Mailbox -Identity $Identity.EntraUPN -Type Shared -ErrorAction Stop
    return "Converted"
}
