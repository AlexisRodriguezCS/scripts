function Test-PasswordExpiry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        # Reminders already sent: key -> date sent
        [Parameter(Mandatory)]
        [hashtable]$SentLog,

        # Injectable for tests
        [datetime]$Today = (Get-Date).Date
    )

    $stepName = "Test-PasswordExpiry"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config, $SentLog, $Today) -StepAction {
        param($PipelineObject, $LogFile, $Config, $SentLog, $Today)

        $raw = $PipelineObject.Raw
        $raw.DaysLeft = ($raw.ExpiresOn.Date - $Today).Days

        if ($raw.DaysLeft -lt 0) {
            $PipelineObject.Status = "Expired"
            return
        }

        # Smallest reminder window the user is inside (e.g. 5 days left -> the 7-day reminder).
        # Picking by window instead of exact day means a missed run still sends the reminder next time.
        $raw.Threshold = @($Config.NotifyDays | Sort-Object | Where-Object { $raw.DaysLeft -le $_ }) | Select-Object -First 1

        if ($null -eq $raw.Threshold) {
            $PipelineObject.Status = "NotDue"
            return
        }

        if (-not $raw.Mail) {
            $PipelineObject.Errors.Add("No email address, can't send reminder")
            $PipelineObject.Status = "Invalid"
            return
        }

        # One reminder per user, per password, per window: re-running the script never sends duplicates
        $raw.SentKey = "$($raw.SamAccountName)|$($raw.ExpiresOn.ToString('yyyy-MM-dd'))|$($raw.Threshold)"

        if ($SentLog.ContainsKey($raw.SentKey)) {
            $PipelineObject.Status = "AlreadySent"
            return
        }

        $PipelineObject.Status = "Due"
        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($raw.SamAccountName) : DUE ($($raw.DaysLeft) days left, $($raw.Threshold)-day reminder)" `
                  -Level "INFO" -LogFile $LogFile
    }
}
