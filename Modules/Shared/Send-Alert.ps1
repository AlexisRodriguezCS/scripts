function Send-Alert {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$Title,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$LogFile
    )

    # Alerts are optional: set AlertWebhookUrl (Teams) and/or AlertEmail + AlertSender in config
    if (-not $Config.AlertWebhookUrl -and -not $Config.AlertEmail) { return }

    # A failed alert must never fail the run itself
    try {
        if ($Config.AlertWebhookUrl) {
            # Teams "Workflows" webhook (Post to a channel when a webhook request is received)
            $card = @{
                type        = "message"
                attachments = @(@{
                    contentType = "application/vnd.microsoft.card.adaptive"
                    content     = @{
                        type    = "AdaptiveCard"
                        version = "1.4"
                        body    = @(
                            @{ type = "TextBlock"; text = $Title; weight = "Bolder"; size = "Medium"; wrap = $true }
                            @{ type = "TextBlock"; text = $Message; wrap = $true }
                        )
                    }
                })
            }
            Invoke-RestMethod -Method Post -Uri $Config.AlertWebhookUrl -ContentType "application/json" `
                              -Body ($card | ConvertTo-Json -Depth 10) -ErrorAction Stop | Out-Null
        }

        if ($Config.AlertEmail) {
            Send-MgUserMail -UserId $Config.AlertSender -ErrorAction Stop -BodyParameter @{
                Message = @{
                    Subject      = $Title
                    Body         = @{ ContentType = "Text"; Content = $Message }
                    ToRecipients = @(@{ EmailAddress = @{ Address = $Config.AlertEmail } })
                }
                SaveToSentItems = $false
            }
        }

        if ($LogFile) { Write-Log -Message "Alert sent: $Title" -Level "INFO" -LogFile $LogFile }
    }
    catch {
        if ($LogFile) { Write-Log -Message "Alert failed: $($_.Exception.Message)" -Level "WARN" -LogFile $LogFile }
    }
}
