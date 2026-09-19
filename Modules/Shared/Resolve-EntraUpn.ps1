function Resolve-EntraUpn {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$SamAccountName,

        # The user's AD UPN (can be empty for a user that doesn't exist yet)
        [string]$AdUpn,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    # Production: AD UPNs use a routable domain (user@contoso.com) and Entra Connect syncs them as-is.
    if ($Config.UseAdUpnForEntra -and $AdUpn) {
        return $AdUpn
    }

    # Lab: AD UPNs end in a non-routable suffix (.local), so Entra Connect falls back to user@tenant.onmicrosoft.com
    return "$SamAccountName@$($Config.TenantDomain)"
}
