function Send-PasswordExpiryEmail {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Raw,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $days = if ($Raw.DaysLeft -eq 1) { "1 day" } elseif ($Raw.DaysLeft -eq 0) { "today" } else { "$($Raw.DaysLeft) days" }

    # Plain language; the template lives in config so HR/IT can change wording without touching code
    $body = $Config.EmailBody `
        -replace '\{Name\}',     $Raw.DisplayName `
        -replace '\{Days\}',     $days `
        -replace '\{Date\}',     $Raw.ExpiresOn.ToString('dddd, MMMM d') `
        -replace '\{ResetUrl\}', $Config.PasswordResetUrl

    $subject = $Config.EmailSubject -replace '\{Days\}', $days

    Send-MgUserMail -UserId $Config.SenderMailbox -ErrorAction Stop -BodyParameter @{
        Message = @{
            Subject      = $subject
            Body         = @{ ContentType = "Text"; Content = $body }
            ToRecipients = @(@{ EmailAddress = @{ Address = $Raw.Mail } })
        }
        SaveToSentItems = $false
    }

    return "Sent ($days left)"
}
