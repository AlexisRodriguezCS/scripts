function ConvertTo-FriendlySignInError {
    [CmdletBinding()]
    param(
        [int]$ErrorCode
    )

    # The Entra sign-in error codes help desks actually run into, in plain words
    $codes = @{
        0      = "Success"
        50126  = "Wrong password"
        50053  = "Account locked (too many wrong passwords)"
        50055  = "Password expired"
        50057  = "Account disabled"
        50034  = "User not found"
        50133  = "Session no longer valid because the password was changed"
        50173  = "Old sign-in token rejected after a password change (the app/device needs the new password)"
        50074  = "MFA required (user was prompted)"
        50076  = "MFA required for this location or app"
        500121 = "MFA not completed (denied, timed out or failed)"
        50158  = "Extra security check not completed"
        53003  = "Blocked by a Conditional Access policy"
        530032 = "Blocked by security policy"
        50097  = "Device authentication required"
        70044  = "Session expired, needs to sign in again"
        50140  = "'Stay signed in?' prompt (not an error)"
        50199  = "Extra confirmation prompt (not an error)"
        81016  = "Seamless SSO sign-in didn't complete (usually harmless)"
    }

    if ($codes.ContainsKey($ErrorCode)) { return $codes[$ErrorCode] }
    return "Error $ErrorCode (look up at https://login.microsoftonline.com/error?code=$ErrorCode)"
}
