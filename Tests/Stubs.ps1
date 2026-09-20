# CI runners don't have RSAT / Microsoft.Graph / ExchangeOnlineManagement / PnP installed, and Pester
# can only mock commands that exist. Define empty stand-ins for any that are missing.
$stubs = @{
    # Active Directory
    'Get-ADUser'                = 'Identity, Filter, Properties, Server, SearchBase'
    'New-ADUser'                = 'Name, DisplayName, GivenName, Surname, SamAccountName, UserPrincipalName, Path, AccountPassword, ChangePasswordAtLogon, Enabled, EmployeeID, Title, Department, Manager, Office, Company'
    'Set-ADUser'                = 'Identity, Replace, Description, Title, Department, Manager, Office, OfficePhone, MobilePhone, Company, EmployeeID, City, State, StreetAddress, PostalCode, ChangePasswordAtLogon, GivenName, Surname, DisplayName, SamAccountName, UserPrincipalName, EmailAddress'
    'Disable-ADAccount'         = 'Identity'
    'Unlock-ADAccount'          = 'Identity'
    'Enable-ADAccount'          = 'Identity'
    'Set-ADAccountPassword'     = 'Identity, NewPassword, [switch]$Reset'
    'Get-ADGroupMember'         = 'Identity'
    'Add-ADGroupMember'         = 'Identity, Members'
    'Remove-ADGroupMember'      = 'Identity, Members'
    'Move-ADObject'             = 'Identity, TargetPath'
    'Rename-ADObject'           = 'Identity, NewName'

    # Microsoft Graph
    'Get-MgUser'                = 'UserId, Property, Filter, [switch]$All'
    'Update-MgUser'             = 'UserId, AccountEnabled, UsageLocation, PasswordProfile'
    'Remove-MgUser'             = 'UserId'
    'Revoke-MgUserSignInSession'= 'UserId'
    'Set-MgUserLicense'         = 'UserId, AddLicenses, RemoveLicenses'
    'Send-MgUserMail'           = 'UserId, BodyParameter'
    'Get-MgSubscribedSku'       = '[switch]$All'
    'Get-MgUserOauth2PermissionGrant' = 'UserId, [switch]$All'
    'Remove-MgOauth2PermissionGrant'  = 'OAuth2PermissionGrantId'
    'Get-MgApplication'         = 'Property, [switch]$All'
    'Get-MgDirectoryRole'       = '[switch]$All'
    'Get-MgDirectoryRoleMember' = 'DirectoryRoleId, [switch]$All'
    'Get-MgReportAuthenticationMethodUserRegistrationDetail' = '[switch]$All'
    'Get-MgSiteListItem'        = 'SiteId, ListId, ExpandProperty, [switch]$All'
    'Update-MgSiteListItemField'= 'SiteId, ListId, ListItemId, BodyParameter'
    'Invoke-MgGraphRequest'     = 'Method, Uri, Body, OutputType'
    'Get-MgDomain'              = '[switch]$All'
    'Get-MgRoleManagementDirectoryRoleDefinition'                 = '[switch]$All'
    'Get-MgRoleManagementDirectoryRoleAssignmentScheduleInstance' = 'ExpandProperty, [switch]$All'
    'Get-MgRoleManagementDirectoryRoleEligibilityScheduleInstance' = 'ExpandProperty, [switch]$All'
    'Get-MgRiskyUser'           = 'Filter, [switch]$All'
    'Get-MgGroup'               = 'Property, Filter, [switch]$All'
    'Get-MgGroupOwner'          = 'GroupId, [switch]$All'
    'Get-MgGroupMember'         = 'GroupId, [switch]$All'
    'Get-MgUserMemberOf'        = 'UserId, [switch]$All'
    'Remove-MgGroupMemberByRef' = 'GroupId, DirectoryObjectId'
    'Remove-MgGroupOwnerByRef'  = 'GroupId, DirectoryObjectId'
    'New-MgGroupOwnerByRef'     = 'GroupId, BodyParameter'
    'Resolve-DnsName'           = 'Name, Type'
    'Get-MgAuditLogSignIn'      = 'Filter, Top, [switch]$All'
    'Get-MgAuditLogDirectoryAudit' = 'Filter, [switch]$All'
    'Get-MgUserAuthenticationMethod' = 'UserId'
    'Get-MgUserAuthenticationTemporaryAccessPassMethod' = 'UserId'
    'New-MgUserAuthenticationTemporaryAccessPassMethod' = 'UserId, BodyParameter'
    'Get-MgSiteListItemVersion' = 'SiteId, ListId, ListItemId, ExpandProperty, [switch]$All'

    # SecretManagement
    'Get-Secret'                = 'Name, Vault, [switch]$AsPlainText'

    # Exchange Online
    'Get-Mailbox'               = 'Identity, ResultSize, RecipientTypeDetails'
    'Set-Mailbox'               = 'Identity, Type, ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward'
    'Add-MailboxPermission'     = 'Identity, User, AccessRights, InheritanceType'
    'Set-MailboxAutoReplyConfiguration' = 'Identity, AutoReplyState, InternalMessage, ExternalMessage, ExternalAudience'
    'Get-Recipient'             = 'Filter, RecipientTypeDetails, ResultSize'
    'Add-DistributionGroupMember'    = 'Identity, Member'
    'Remove-DistributionGroupMember' = 'Identity, Member, [switch]$BypassSecurityGroupManagerCheck'
    'Get-AcceptedDomain'        = ''
    'Get-InboxRule'             = 'Mailbox'
    'Get-EXOMailbox'            = 'RecipientTypeDetails, ResultSize, Properties'
    'Get-EXOMailboxStatistics'  = 'Identity'
    'Get-User'                  = 'Identity'
    'Get-MailboxPermission'     = 'Identity'
    'Get-RecipientPermission'   = 'Identity'
    'Disable-InboxRule'         = 'Identity, Mailbox'

    # PnP (SharePoint)
    'Get-PnPUserProfileProperty' = 'Account'
    'Set-PnPTenantSite'         = 'Identity, Owners'
    'Get-PnPTenantSite'         = 'Identity, [switch]$IncludeOneDriveSites'
    'Get-PnPExternalUser'       = 'PageSize, Position'

    # Intune
    'Get-MgDeviceManagementManagedDevice'          = 'Property, Filter, [switch]$All'
    'Invoke-MgRetireDeviceManagementManagedDevice' = 'ManagedDeviceId'
    'Remove-MgDeviceManagementManagedDevice'       = 'ManagedDeviceId'
    'Get-MgUserManagedDevice'                      = 'UserId, Property, [switch]$All'
}

foreach ($name in $stubs.Keys) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        $params = ($stubs[$name] -split ',\s*' | Where-Object { $_ } | ForEach-Object { if ($_ -like '*$*') { $_ } else { "`$$_" } }) -join ', '
        Set-Item "function:global:$name" ([scriptblock]::Create("[CmdletBinding(SupportsShouldProcess)] param($params)"))
    }
}
