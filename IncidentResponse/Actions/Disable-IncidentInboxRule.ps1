function Disable-IncidentInboxRule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$RuleIdentity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Disabled rather than deleted, so investigators can still see exactly what it did
    Disable-InboxRule -Identity $RuleIdentity -Mailbox $Identity.EntraUPN -Confirm:$false -ErrorAction Stop
    return "Rule disabled"
}
