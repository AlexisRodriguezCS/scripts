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

    # Wording lives in config so it can change without touching code
    $body = $Config.EmailBody `
        -replace '\{Name\}',    $Raw.DisplayName `
        -replace '\{Percent\}', $Raw.PercentUsed `
        -replace '\{Used\}',    $Raw.UsedGB `
        -replace '\{Quota\}',   $Raw.QuotaGB

    Send-MgUserMail -UserId $Config.SenderMailbox -ErrorAction Stop -BodyParameter @{
        Message = @{
            Subject      = $Config.EmailSubject -replace '\{Percent\}', $Raw.PercentUsed
            Body         = @{ ContentType = "Text"; Content = $body }
            ToRecipients = @(@{ EmailAddress = @{ Address = $Raw.Mail } })
        }
        SaveToSentItems = $false
    }

    return "Sent ($($Raw.PercentUsed)% full)"
}
