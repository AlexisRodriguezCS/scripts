function Invoke-UserMover {
    [CmdletBinding()]
    param(
        # One or more rows (from a CSV, or built from parameters for a single person)
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Requests,
        [Parameter(Mandatory)]
        [string]$LogFile,
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [bool]$Apply
    )

    $pipelineStart = Get-Date
    $runStamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir     = "$PSScriptRoot\..\..\Reports"

    # 1. Build requests
    $users = @($Requests | ForEach-Object { New-MoverRequest -Row $_ -LogFile $LogFile })

    Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile

    foreach ($user in $users) {
        # 2. Validate
        Test-MoverData -PipelineObject $user -LogFile $LogFile -Config $Config
        # 3. Look up user (and new manager) in AD
        Get-MoverIdentity -PipelineObject $user -LogFile $LogFile -Config $Config
        # 4. Decide the new access with the same rules as onboarding
        if ($user.Status -eq "Valid") { Set-OnboardingPolicy -PipelineObject $user -LogFile $LogFile -Config $Config }
        # 5. Plan the difference between old and new
        New-MoverPlan -PipelineObject $user -LogFile $LogFile -Config $Config
        # 6. Execute
        if ($Apply) {
            $null = Start-Mover -PipelineObject $user -LogFile $LogFile -Config $Config -SnapshotFolder "$reportDir\Snapshots\Mover_$runStamp"
        } else {
            Write-Log -Message "[$($user.CorrelationId)] [DRY RUN] Not moving: $($user.Raw.SamAccountName)" -Level "INFO" -LogFile $LogFile
        }
        Write-Log -Message "--------------------------------------------------------" -LogFile $LogFile
    }

    # Count from final status so failures in any step are included
    $movedCount  = @($users | Where-Object Status -eq "Moved").Count
    $failedCount = @($users | Where-Object Status -in @("Failed", "Invalid", "NotFound")).Count

    Write-Log -Message "=== Pipeline Finished === Total: $($users.Count) | Moved: $movedCount | Failed: $failedCount | Duration: $(((Get-Date) - $pipelineStart).TotalSeconds) sec" `
        -Level "INFO" -LogFile $LogFile

    # 7. Report
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\MoverReport_$runStamp.txt"
    $null = New-Report -Users $users -ReportFile $reportFile
    Write-Log -Message "Report generated: $reportFile" -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Total      = $users.Count
        Moved      = $movedCount
        Failed     = $failedCount
        ReportFile = $reportFile
        Users      = @($users | ForEach-Object {
            [pscustomobject]@{ SamAccountName = $_.Raw.SamAccountName; Status = $_.Status; Errors = ($_.Errors | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.Message } }) -join '; ' }
        })
    }
}
