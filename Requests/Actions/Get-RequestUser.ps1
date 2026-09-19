function Get-RequestUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    # Returns @{ User; Problem } so every help desk request refuses the same way
    if ($SamAccountName -notmatch '^[^"/\\\[\]:;|=,+*?<>@'' ]{1,20}$') {
        return @{ Problem = "'$SamAccountName' isn't a valid username" }
    }

    $user = Get-ADUser -Filter "SamAccountName -eq '$SamAccountName'" -Properties LockedOut, adminCount, Enabled, DisplayName -ErrorAction Stop
    if (-not $user) {
        return @{ Problem = "No account found with username $SamAccountName" }
    }

    # Admin and VIP accounts are never changed from a request
    $protected = Test-ProtectedAccount -AdUser $user -Config $Config
    if ($protected) {
        return @{ Problem = $protected }
    }

    return @{ User = $user }
}
