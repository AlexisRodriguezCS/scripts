function Test-MailboxQuota {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        # Warnings already sent: key -> date sent
        [Parameter(Mandatory)]
        [hashtable]$SentLog,

        # Injectable for tests
        [datetime]$Today = (Get-Date).Date
    )

    $stepName = "Test-MailboxQuota"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config, $SentLog, $Today) -StepAction {
        param($PipelineObject, $LogFile, $Config, $SentLog, $Today)

        $raw = $PipelineObject.Raw

        # Highest warning level reached (e.g. 92% full -> the 90% warning)
        $raw.Threshold = @($Config.WarnAtPercent | Sort-Object -Descending | Where-Object { $raw.PercentUsed -ge $_ }) | Select-Object -First 1

        if ($null -eq $raw.Threshold) {
            $PipelineObject.Status = "Ok"
            return
        }

        # One warning per level per month, so people aren't emailed every day
        $raw.SentKey = "$($raw.Mail)|$($raw.Threshold)|$($Today.ToString('yyyy-MM'))"

        if ($SentLog.ContainsKey($raw.SentKey)) {
            $PipelineObject.Status = "AlreadySent"
            return
        }

        $PipelineObject.Status = "Due"
        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($raw.Mail) : DUE ($($raw.PercentUsed)% of $($raw.QuotaGB) GB)" `
                  -Level "INFO" -LogFile $LogFile
    }
}
