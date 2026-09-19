function Revoke-OffboardingSession {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Sign the user out of every M365 session and invalidate refresh tokens
    $null = Revoke-MgUserSignInSession -UserId $Identity.EntraUPN -ErrorAction Stop
    return "Revoked"
}
