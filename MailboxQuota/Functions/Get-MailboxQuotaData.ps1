function ConvertTo-Bytes {
    # Exchange sizes look like "49.5 GB (53,150,220,288 bytes)" or "Unlimited"
    param([string]$Size)
    if ($Size -match '\(([\d,]+) bytes\)') { return [double]($Matches[1] -replace ',', '') }
    return $null
}

function Get-MailboxQuotaData {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    Write-Log -Message "[Get-MailboxQuotaData] Fetching user mailboxes" -Level "DEBUG" -LogFile $LogFile

    $mailboxes = Get-EXOMailbox -RecipientTypeDetails UserMailbox -ResultSize Unlimited `
                                -Properties ProhibitSendQuota, DisplayName -ErrorAction Stop

    # ponytail: one statistics call per mailbox; fine for a few thousand, use a scheduled report export beyond that
    $pipelineObjects = foreach ($mailbox in $mailboxes) {
        $quota = ConvertTo-Bytes "$($mailbox.ProhibitSendQuota)"
        if (-not $quota) { continue }   # unlimited mailboxes can't fill up

        $stats = Get-EXOMailboxStatistics -Identity $mailbox.UserPrincipalName -ErrorAction SilentlyContinue
        $used  = ConvertTo-Bytes "$($stats.TotalItemSize)"
        if ($null -eq $used) { continue }

        [pscustomobject]@{
            CorrelationId = [guid]::NewGuid().ToString()
            Raw    = [pscustomobject]@{
                SamAccountName = $mailbox.UserPrincipalName   # Name shown in reports
                DisplayName    = $mailbox.DisplayName
                Mail           = $mailbox.UserPrincipalName
                UsedGB         = [math]::Round($used / 1GB, 1)
                QuotaGB        = [math]::Round($quota / 1GB, 1)
                PercentUsed    = [math]::Round(100 * $used / $quota, 1)
                Threshold      = $null
                SentKey        = $null
            }
            Errors = [System.Collections.Generic.List[object]]::new()
            Plan   = @()
            Identity = $null
            Status  = "Pending"   # Ok | Due | AlreadySent | Sent | Failed
            StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
            StepDurations  = @{}
        }
    }

    Write-Log -Message "[Get-MailboxQuotaData] Checked $(@($pipelineObjects).Count) mailboxes" -Level "INFO" -LogFile $LogFile

    return $pipelineObjects
}
