function Grant-OffboardingMailboxAccess {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Give the delegate (usually the manager) full access to the shared mailbox
    $null = Add-MailboxPermission -Identity $Identity.EntraUPN -User $Target -AccessRights FullAccess -InheritanceType All -ErrorAction Stop
    return "Granted"
}
