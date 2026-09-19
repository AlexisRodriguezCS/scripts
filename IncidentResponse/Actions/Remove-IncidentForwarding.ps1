function Remove-IncidentForwarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # The old values are already in the evidence folder
    Set-Mailbox -Identity $Identity.EntraUPN -ForwardingSmtpAddress $null -ForwardingAddress $null -DeliverToMailboxAndForward $false -ErrorAction Stop
    return "Forwarding removed"
}
