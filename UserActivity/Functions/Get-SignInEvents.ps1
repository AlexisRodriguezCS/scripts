function Get-SignInEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$UserId,
        [Parameter(Mandatory)] [datetime]$Since
    )

    # Interactive sign-ins (needs Entra ID P1 + AuditLog.Read.All; Entra keeps 30 days)
    $filter  = "userId eq '$UserId' and createdDateTime ge $($Since.ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ'))"
    $signIns = @(Get-MgAuditLogSignIn -Filter $filter -All -ErrorAction Stop)

    foreach ($signIn in $signIns) {
        $code = [int]$signIn.Status.ErrorCode

        # Which Conditional Access policy blocked it, if any
        $blockedBy = @($signIn.AppliedConditionalAccessPolicies | Where-Object { $_.Result -eq "failure" } | ForEach-Object { $_.DisplayName })

        $where = @($signIn.Location.City, $signIn.Location.CountryOrRegion) | Where-Object { $_ }
        $device = @($signIn.DeviceDetail.OperatingSystem, $signIn.DeviceDetail.Browser) | Where-Object { $_ }

        New-ActivityEvent -Time $signIn.CreatedDateTime -Source "Sign-in" `
            -Event "$(if ($code -eq 0) { 'Signed in' } else { 'Sign-in failed' }): $(ConvertTo-FriendlySignInError -ErrorCode $code)$(if ($blockedBy) { " ($($blockedBy -join ', '))" })" `
            -Detail "App: $($signIn.AppDisplayName) | Client: $($signIn.ClientAppUsed) | Device: $($device -join ' / ') | IP: $($signIn.IPAddress) | $($where -join ', ')" `
            -Result $(if ($code -eq 0) { "Success" } else { "Failure" }) -ErrorCode $code
    }
}
