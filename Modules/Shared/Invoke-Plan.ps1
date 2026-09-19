function Invoke-Plan {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        # Action name -> @{ Run = { param($PipelineObject, $Target, $PlanItem) ... }; MaxRetries = 3; DelaySeconds = 5 }
        [Parameter(Mandatory)]
        [hashtable]$Actions,

        # Optional: raw action result -> report text ({0} = target), e.g. @{ Removed = "Removed from {0}" }
        [hashtable]$ResultText = @{},

        # Actions that must succeed or the rest of the plan is skipped (e.g. disabling the account)
        [string[]]$StopOnFailure = @(),

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $correlationId = $PipelineObject.CorrelationId.Substring(0,8)

    foreach ($actionItem in $PipelineObject.Plan) {
        $action = $actionItem.Action
        $target = $actionItem.Target
        $actionItem.Result = $null

        if (-not $Actions.ContainsKey($action)) {
            Add-PipelineError -PipelineObject $PipelineObject -Step $action -Message "Unknown action: $action" -LogFile $LogFile
            Write-Log -Message "[$correlationId] $action -> $target : FAILED (unknown action)" -Level "ERROR" -LogFile $LogFile
            return $false
        }

        $retryParams = $Actions[$action]

        for ($attempt = 1; $attempt -le $retryParams.MaxRetries; $attempt++) {
            try {
                # Call action function
                $result = & $retryParams.Run $PipelineObject $target $actionItem

                # Results for reporting
                $actionItem.Result = if ($ResultText.ContainsKey("$result")) { $ResultText["$result"] -f $target } else { $result }

                Write-Log -Message "[$correlationId] $action -> $target : $($actionItem.Result)" -Level "INFO" -LogFile $LogFile
                break
            }
            catch {
                if ($attempt -lt $retryParams.MaxRetries) {
                    # Backoff grows each attempt, jitter so parallel runs don't retry in lockstep
                    Write-Log -Message "[$correlationId] $action -> $target : RETRY ($attempt) $($_.Exception.Message)" -Level "WARN" -LogFile $LogFile
                    Start-Sleep -Seconds (($retryParams.DelaySeconds * $attempt) + (Get-Random -Minimum 1 -Maximum 3))
                }
                else {
                    # All retries exhausted → mark structured pipeline error
                    Add-PipelineError -PipelineObject $PipelineObject -Step $action -Message "Failed during $action → $target" `
                                      -Exception $_.Exception -LogFile $LogFile
                    $actionItem.Result = "Failed"
                    Write-Log -Message "[$correlationId] $action -> $target : FAILED" -Level "ERROR" -LogFile $LogFile
                }
            }
        }

        if ($actionItem.Result -eq "Failed" -and $action -in $StopOnFailure) {
            Write-Log -Message "[$correlationId] $action failed, skipping the rest of the plan" -Level "ERROR" -LogFile $LogFile
            return $false
        }
    }

    return ($PipelineObject.Errors.Count -eq 0)
}
