function Invoke-UserOffboarding {
    [CmdletBinding()]
    param(
        [string]$Path, # CSV path (bulk)
        [PSCustomObject[]]$Rows, # or rows built from parameters (single)
        [Parameter(Mandatory)]
        [string]$LogFile, # Log file path
        [Parameter(Mandatory)]
        [PSCustomObject]$Config, # Get config object
        [bool]$Apply
    )

    $pipelineStart = Get-Date
    $runStamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir     = "$PSScriptRoot\..\..\Reports"
    $snapshotDir   = "$reportDir\Snapshots\Offboarding_$runStamp"

    # Call import function
    $users = if ($Rows) { Import-OffboardingCsv -Rows $Rows -LogFile $LogFile } else { Import-OffboardingCsv -Path $Path -LogFile $LogFile }

    Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile

    $processed = @()

    foreach ($user in $users) {
        # 1. Validate data
        Test-OffboardingData -PipelineObject $user -LogFile $LogFile

        # User failed validation
        if ($user.Status -eq "Invalid") {
            Write-Log -Message "[$($user.CorrelationId)] [INVALID] Validation failed: $($user.Raw.SamAccountName)" `
                -Level "ERROR" -LogFile $LogFile
            continue
        }

        # 2. Look up user in AD
        Get-OffboardingIdentity -PipelineObject $user -LogFile $LogFile -Config $Config
        # 3. Plan offboarding actions
        New-OffboardingPlan -PipelineObject $user -LogFile $LogFile -Config $Config
        # 4. Execute plan
        if ($Apply) {
            $null = Start-Offboarding -PipelineObject $user -LogFile $LogFile -Config $Config -SnapshotFolder $snapshotDir
        } else {
            Write-Log -Message "[$($user.CorrelationId)] [DRY RUN] Not offboarding user: $($user.Raw.SamAccountName)" `
                -Level "INFO" -LogFile $LogFile
        }
        # Log line break
        Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile

        # Stop the run if the same failure keeps repeating (M365 down, expired certificate, lost permission)
        $processed += $user
        if (Test-CircuitBreaker -Processed $processed -Config $Config -LogFile $LogFile) {
            foreach ($rest in $users | Where-Object Status -eq "Pending") { $rest.Status = "Stopped" }
            break
        }
    }

    # Count from final status so failures in any step are included
    $offboardedCount = @($users | Where-Object Status -eq "Offboarded").Count
    $notFoundCount   = @($users | Where-Object Status -eq "NotFound").Count
    $failedCount     = @($users | Where-Object Status -in @("Failed","Invalid")).Count
    $stoppedCount    = @($users | Where-Object Status -eq "Stopped").Count

    $pipelineDuration = (Get-Date) - $pipelineStart

    # Finish logging
    Write-Log -Message "
    === Pipeline Finished ===
    Total: $(@($users).Count)
    Offboarded: $offboardedCount
    Not Found: $notFoundCount
    Failed: $failedCount
    Stopped: $stoppedCount
    Total Duration: $($pipelineDuration.TotalSeconds) sec
        " -Level "INFO" -LogFile $LogFile

    # Generate report
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\OffboardingReport_$runStamp.txt"
    $null = New-Report -Users $users -ReportFile $reportFile
    Write-Log -Message "Report generated: $reportFile" -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Total       = @($users).Count
        Offboarded  = $offboardedCount
        NotFound    = $notFoundCount
        Failed      = $failedCount
        Stopped     = $stoppedCount
        DurationSec = $pipelineDuration.TotalSeconds
        ReportFile  = $reportFile
        Users       = @($users | ForEach-Object {
            [pscustomobject]@{
                SamAccountName = $_.Raw.SamAccountName
                Status         = $_.Status
                Errors         = ($_.Errors | ForEach-Object { if ($_ -is [string]) { $_ } else { "$($_.Step): $($_.Exception)" } }) -join '; '
            }
        })
    }
}
