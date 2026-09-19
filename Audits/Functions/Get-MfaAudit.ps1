function Get-MfaAudit {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    # Registration details report (needs Entra ID P1 and AuditLog.Read.All)
    $details = Get-MgReportAuthenticationMethodUserRegistrationDetail -All -ErrorAction Stop

    # Methods that can be phished or SIM-swapped
    $weakMethods = @("mobilePhone", "alternateMobilePhone", "officePhone", "email")

    foreach ($user in $details | Where-Object { $_.UserType -ne "guest" }) {
        $methods = @($user.MethodsRegistered)
        $strong  = @($methods | Where-Object { $_ -notin $weakMethods })

        $flagged = $false
        $reason  = $null

        if (-not $user.IsMfaRegistered) {
            $flagged = $true
            $reason  = "No MFA method registered"
        }
        elseif ($user.IsAdmin -and $strong.Count -eq 0) {
            $flagged = $true
            $reason  = "Admin relies on SMS/voice/email only"
        }

        New-AuditFinding -Check "Mfa" -Name $user.UserPrincipalName `
                         -Detail "Admin: $($user.IsAdmin) | Methods: $($methods -join ', ')" `
                         -Flagged $flagged -Reason $reason
    }
}
