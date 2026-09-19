function Set-OffboardingAutoReply {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Check if user has a mailbox
    $mailbox = Get-Mailbox -Identity $Identity.EntraUPN -ErrorAction SilentlyContinue

    if ($null -eq $mailbox) {
        return "NoMailbox"
    }

    # Fill in the message template from config
    $message = $Config.AutoReplyMessage `
        -replace '\{Name\}',    $Identity.DisplayName `
        -replace '\{Contact\}', $Target

    Set-MailboxAutoReplyConfiguration -Identity $Identity.EntraUPN `
        -AutoReplyState Enabled `
        -InternalMessage $message `
        -ExternalMessage $message `
        -ExternalAudience All `
        -ErrorAction Stop

    return "Enabled"
}
