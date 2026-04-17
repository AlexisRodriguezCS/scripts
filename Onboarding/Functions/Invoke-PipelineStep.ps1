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
        [scriptblock]$StepAction,

        [Parameter()]
        [object[]]$StepArgs = @()  
    )

    # Skip if the pipeline is already invalid or failed
    if ($PipelineObject.Status -in @("Failed","Invalid")) { return }

    # Skip if this step already completed
    if ($PipelineObject.StepsCompleted.Contains($StepName)) { return }

    Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$StepName] Starting step" `
        -Level "DEBUG" -LogFile $LogFile

    $start = Get-Date

    try {
        # Execute the actual step action
        & $StepAction $PipelineObject $LogFile @StepArgs

        # Mark step complete
        $PipelineObject.StepsCompleted.Add($StepName) | Out-Null

        # Track duration
        $duration = (Get-Date) - $start
        $PipelineObject.StepDurations[$StepName] = $duration.TotalSeconds

        # Log completion
        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$StepName] Step completed in $($duration.TotalSeconds) seconds" `
                  -Level "DEBUG" -LogFile $LogFile
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
        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$StepName] Step failed after $($duration.TotalSeconds) seconds: $($_.Exception.Message)" `
                  -Level "ERROR" -LogFile $LogFile
    }
}