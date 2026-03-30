function Invoke-PipelineStep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$StepName,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [scriptblock]$StepAction
    )

    # Skip if the pipeline is already skipped or failed
    if ($PipelineObject.Status -in @("Skipped","Failed")) { return }

    # Skip if this step already completed
    if ($PipelineObject.StepsCompleted.Contains($StepName)) { return }

    Write-Log -Message "[$($PipelineObject.CorrelationId)] [$StepName] Starting step" `
        -Level "INFO" -LogFile $LogFile

    $start = Get-Date

    try {
        # Execute the actual step action
        & $StepAction $PipelineObject

        # Mark step complete
        $PipelineObject.StepsCompleted.Add($StepName) | Out-Null

        # Track duration
        $duration = (Get-Date) - $start
        $PipelineObject.StepDurations[$StepName] = $duration.TotalSeconds

        # Log completion
        Write-Log -Message "[$($PipelineObject.CorrelationId)] [$StepName] Step completed in $($duration.TotalSeconds) seconds" `
                  -Level "INFO" -LogFile $LogFile
    }
    catch {
        # Capture the error
        Add-PipelineError -PipelineObject $PipelineObject -Step $StepName `
            -Message "Step failed" -Exception $_.Exception

        # Mark as failed
        $PipelineObject.Status = "Failed"

        # Track duration even on failure
        $duration = (Get-Date) - $start
        $PipelineObject.StepDurations[$StepName] = $duration.TotalSeconds

        # Log failure
        Write-Log -Message "[$($PipelineObject.CorrelationId)] [$StepName] Step failed after $($duration.TotalSeconds) seconds: $($_.Exception.Message)" `
                  -Level "ERROR" -LogFile $LogFile
    }
}