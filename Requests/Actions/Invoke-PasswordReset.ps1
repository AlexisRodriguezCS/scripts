function Invoke-PasswordReset {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Random temp password, emailed to IT once, must be changed at next sign-in')]
    param(
        [Parameter(Mandatory)] [string]$SamAccountName,
        [Parameter(Mandatory)] [PSCustomObject]$Config,
        [bool]$Apply
    )

    $lookup = Get-RequestUser -SamAccountName $SamAccountName -Config $Config
    if ($lookup.Problem) { return @{ Ok = $false; Message = "Needs attention: $($lookup.Problem)" } }

    if (-not $Apply) { return @{ Ok = $true; Message = "[Preview, nothing changed] Would reset the password for $SamAccountName." } }

    $user     = $lookup.User
    $password = New-RandomPassword

    # Reset, unlock if needed, and force a new password at next sign-in
    Set-ADAccountPassword -Identity $user.DistinguishedName -NewPassword (ConvertTo-SecureString $password -AsPlainText -Force) -Reset -ErrorAction Stop
    Set-ADUser -Identity $user.DistinguishedName -ChangePasswordAtLogon $true -ErrorAction Stop
    if ($user.LockedOut) { Unlock-ADAccount -Identity $user.DistinguishedName -ErrorAction Stop }

    # The password goes to IT by email, never into the SharePoint list (anyone who can read the list would see it)
    Send-MgUserMail -UserId $Config.SenderMailbox -ErrorAction Stop -BodyParameter @{
        Message = @{
            Subject      = "Password reset: $($user.DisplayName)"
            Body         = @{ ContentType = "Text"; Content = "Username: $SamAccountName`nTemporary password: $password`nThey must change it at next sign-in. Hand it over in person or by phone, not email." }
            ToRecipients = @(@{ EmailAddress = @{ Address = $Config.TempPasswordRecipient } })
        }
        SaveToSentItems = $false
    }

    return @{ Ok = $true; Message = "Password reset for $SamAccountName. IT has the temporary password and will give it to them; they'll pick a new one at sign-in." }
}
