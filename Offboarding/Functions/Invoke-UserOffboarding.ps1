function Invoke-UserOffboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path, # CSV path
        [Parameter(Mandatory)]
        [string]$LogFile, # Log file path
        [Parameter(Mandatory)]
        [PSCustomObject]$Config, # Get config object
        [bool]$Apply
    )

    $pipelineStart = Get-Date

    # Call import function
    $users = Import-OffboardingCsv -Path $Path -LogFile $LogFile

    Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile

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
            $null = Start-Offboarding -PipelineObject $user -LogFile $LogFile -Config $Config
        } else {
            Write-Log -Message "[$($user.CorrelationId)] [DRY RUN] Not offboarding user: $($user.Raw.SamAccountName)" `
                -Level "INFO" -LogFile $LogFile
        }
        # Log line break
        Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile
    }

    # Count from final status so failures in any step are included
    $offboardedCount = @($users | Where-Object Status -eq "Offboarded").Count
    $notFoundCount   = @($users | Where-Object Status -eq "NotFound").Count
    $failedCount     = @($users | Where-Object Status -in @("Failed","Invalid")).Count

    $pipelineDuration = (Get-Date) - $pipelineStart

    # Finish logging
    Write-Log -Message "
    === Pipeline Finished ===
    Total: $(@($users).Count)
    Offboarded: $offboardedCount
    Not Found: $notFoundCount
    Failed: $failedCount
    Total Duration: $($pipelineDuration.TotalSeconds) sec
        " -Level "INFO" -LogFile $LogFile

    # Generate report
    $reportDir  = "$PSScriptRoot\..\..\Reports"
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\OffboardingReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    $null = New-Report -Users $users -ReportFile $reportFile
    Write-Log -Message "Report generated: $reportFile" -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Total       = @($users).Count
        Offboarded  = $offboardedCount
        NotFound    = $notFoundCount
        Failed      = $failedCount
        DurationSec = $pipelineDuration.TotalSeconds
    }
}
