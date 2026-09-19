# CI runners don't have RSAT / Microsoft.Graph / ExchangeOnlineManagement installed, and Pester
# can only mock commands that exist. Define empty stand-ins for any that are missing.
$stubs = @{
    'Get-ADUser'                = 'Identity, Filter, Properties, Server'
    'New-ADUser'                = 'Name, GivenName, Surname, SamAccountName, UserPrincipalName, Path, AccountPassword, ChangePasswordAtLogon, Enabled'
    'Disable-ADAccount'         = 'Identity'
    'Set-ADAccountPassword'     = 'Identity, NewPassword, [switch]$Reset'
    'Set-ADUser'                = 'Identity, Description'
    'Remove-ADGroupMember'      = 'Identity, Members'
    'Move-ADObject'             = 'Identity, TargetPath'
    'Get-MgUser'                = 'UserId, Property'
    'Revoke-MgUserSignInSession'= 'UserId'
    'Set-MgUserLicense'         = 'UserId, AddLicenses, RemoveLicenses'
    'Get-Mailbox'               = 'Identity'
    'Set-Mailbox'               = 'Identity, Type'
    'Add-MailboxPermission'     = 'Identity, User, AccessRights, InheritanceType'
    'Set-MailboxAutoReplyConfiguration' = 'Identity, AutoReplyState, InternalMessage, ExternalMessage, ExternalAudience'
    'Get-PnPUserProfileProperty' = 'Account'
    'Get-Recipient'             = 'Filter, RecipientTypeDetails, ResultSize'
    'Remove-DistributionGroupMember' = 'Identity, Member, [switch]$BypassSecurityGroupManagerCheck'
    'Set-PnPTenantSite'         = 'Identity, Owners'
}

foreach ($name in $stubs.Keys) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        $params = ($stubs[$name] -split ',\s*' | ForEach-Object { if ($_ -like '*$*') { $_ } else { "`$$_" } }) -join ', '
        Set-Item "function:global:$name" ([scriptblock]::Create("[CmdletBinding(SupportsShouldProcess)] param($params)"))
    }
}
