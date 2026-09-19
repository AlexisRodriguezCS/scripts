function Invoke-MailboxQuotaWarning {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogFile,
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        # Where sent warnings are remembered between runs
        [Parameter(Mandatory)]
        [string]$SentLogPath,
        [bool]$Apply
    )

    $runStamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir = "$PSScriptRoot\..\..\Reports"

    # Load what was already sent; keep ~2 months so the file doesn't grow forever
    $sentLog = @{}
    if (Test-Path $SentLogPath) {
        $saved = Get-Content $SentLogPath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in $saved.Keys) {
            if ([datetime]$saved[$key] -gt (Get-Date).AddDays(-62)) { $sentLog[$key] = $saved[$key] }
        }
    }

    $actions = @{
        SendWarning = @{ MaxRetries = 3; DelaySeconds = 10; Run = { param($p, $t) Send-MailboxQuotaWarning -Raw $p.Raw -Config $Config -LogFile $LogFile } }
    }

    # 1. Mailbox sizes
    $mailboxes = @(Get-MailboxQuotaData -LogFile $LogFile)

    foreach ($mailbox in $mailboxes) {
        # 2. Decide: fine, due a warning, or already warned this month
        Test-MailboxQuota -PipelineObject $mailbox -LogFile $LogFile -Config $Config -SentLog $sentLog
        if ($mailbox.Status -ne "Due") { continue }

        # 3. Plan + send
        $mailbox.Plan = @(@{ Action = "SendWarning"; Target = $mailbox.Raw.Mail; Result = $null })
        if ($Apply) {
            if (Invoke-Plan -PipelineObject $mailbox -Actions $actions -LogFile $LogFile) {
                $sentLog[$mailbox.Raw.SentKey] = (Get-Date).ToString('yyyy-MM-dd')
                $mailbox.Status = "Sent"
            } else {
                $mailbox.Status = "Failed"
            }
        }
    }

    if ($Apply) { $sentLog | ConvertTo-Json | Out-File -FilePath $SentLogPath -Encoding utf8 }

    # 4. Report (only mailboxes over a warning level)
    $reported = @($mailboxes | Where-Object Status -ne "Ok")
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\MailboxQuotaReport_$runStamp.txt"
    $null = New-Report -Users $reported -ReportFile $reportFile

    return [pscustomobject]@{
        Checked     = $mailboxes.Count
        OverLimit   = $reported.Count
        Sent        = @($mailboxes | Where-Object Status -eq "Sent").Count
        AlreadySent = @($mailboxes | Where-Object Status -eq "AlreadySent").Count
        Failed      = @($mailboxes | Where-Object Status -eq "Failed").Count
        ReportFile  = $reportFile
    }
}
