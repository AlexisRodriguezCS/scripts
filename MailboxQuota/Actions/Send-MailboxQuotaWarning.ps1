function Send-MailboxQuotaWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Raw,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Wording lives in config so it can change without touching code.
    # .Replace() and not -replace: a name like "O'Neil $ Co" would be read as a regex substitution
    $body = $Config.EmailBody.
        Replace('{Name}',    "$($Raw.DisplayName)").
        Replace('{Percent}', "$($Raw.PercentUsed)").
        Replace('{Used}',    "$($Raw.UsedGB)").
        Replace('{Quota}',   "$($Raw.QuotaGB)")

    Send-MgUserMail -UserId $Config.SenderMailbox -ErrorAction Stop -BodyParameter @{
        Message = @{
            Subject      = $Config.EmailSubject.Replace('{Percent}', "$($Raw.PercentUsed)")
            Body         = @{ ContentType = "Text"; Content = $body }
            ToRecipients = @(@{ EmailAddress = @{ Address = $Raw.Mail } })
        }
        SaveToSentItems = $false
    }

    return "Sent ($($Raw.PercentUsed)% full)"
}
