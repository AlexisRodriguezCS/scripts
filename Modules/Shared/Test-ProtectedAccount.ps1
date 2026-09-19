function Test-ProtectedAccount {
    [CmdletBinding()]
    param(
        # AD user loaded with the adminCount property
        [Parameter(Mandatory)]
        [PSCustomObject]$AdUser,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    # Returns why the account is protected, or $null if it isn't.
    # IT can override by running the script by hand with -AllowProtected; the HR request queue never can.
    if ($Config.AllowProtected) { return $null }

    # adminCount = 1: AD marks every member (current or past) of Domain Admins, Enterprise Admins, etc.
    if ($AdUser.adminCount -eq 1) {
        return "Protected account (AD admin). IT must run this by hand with -AllowProtected."
    }

    # VIPs, break-glass and service accounts listed per client
    if ($AdUser.SamAccountName -in @($Config.ProtectedAccounts)) {
        return "Protected account (on the ProtectedAccounts list). IT must run this by hand with -AllowProtected."
    }

    return $null
}
