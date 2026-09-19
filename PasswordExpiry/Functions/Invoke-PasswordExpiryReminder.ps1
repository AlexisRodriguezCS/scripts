function Invoke-PasswordExpiryReminder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogFile,
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        # Where sent reminders are remembered between runs
        [Parameter(Mandatory)]
        [string]$SentLogPath,
        [bool]$Apply
    )

    $pipelineStart = Get-Date
    $runStamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir     = "$PSScriptRoot\..\..\Reports"

    # Load what was already sent; drop entries older than 60 days so the file doesn't grow forever
    $sentLog = @{}
    if (Test-Path $SentLogPath) {
        $saved = Get-Content $SentLogPath -Raw | ConvertFrom-Json -AsHashtable
        foreach ($key in $saved.Keys) {
            if ([datetime]$saved[$key] -gt (Get-Date).AddDays(-60)) { $sentLog[$key] = $saved[$key] }
        }
    }

    # 1. Get users whose passwords expire
    $users = @(Get-PasswordExpiryData -Config $Config -LogFile $LogFile)

    foreach ($user in $users) {
        # 2. Decide: not due, due, already reminded, expired
        Test-PasswordExpiry -PipelineObject $user -LogFile $LogFile -Config $Config -SentLog $sentLog
        # 3. Plan the email
        New-PasswordExpiryPlan -PipelineObject $user -LogFile $LogFile
        # 4. Send
        if ($Apply) {
            $null = Start-PasswordExpiryReminder -PipelineObject $user -LogFile $LogFile -Config $Config -SentLog $sentLog
        }
    }

    if ($Apply) {
        $sentLog | ConvertTo-Json | Out-File -FilePath $SentLogPath -Encoding utf8
    } else {
        Write-Log -Message "[DRY RUN] $(@($users | Where-Object Status -eq 'Due').Count) reminders would be sent" -Level "INFO" -LogFile $LogFile
    }

    # 5. Report (skip users who aren't due, there can be thousands)
    $reported = @($users | Where-Object Status -ne "NotDue")

    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\PasswordExpiryReport_$runStamp.txt"
    $null = New-Report -Users $reported -ReportFile $reportFile

    Write-Log -Message "=== Pipeline Finished === Checked: $($users.Count) | Sent: $(@($users | Where-Object Status -eq 'Sent').Count) | Duration: $(((Get-Date) - $pipelineStart).TotalSeconds) sec" `
              -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Checked     = $users.Count
        Due         = @($users | Where-Object Status -in @("Due", "Sent")).Count
        Sent        = @($users | Where-Object Status -eq "Sent").Count
        AlreadySent = @($users | Where-Object Status -eq "AlreadySent").Count
        Expired     = @($users | Where-Object Status -eq "Expired").Count
        Failed      = @($users | Where-Object Status -in @("Failed", "Invalid")).Count
        ReportFile  = $reportFile
    }
}
