function Start-Onboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $correlationId = $PipelineObject.CorrelationId.Substring(0,8)
    $displayName   = $PipelineObject.Identity.DisplayName

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -in @("Skipped","Failed")) {
        Write-Log -Message "[$correlationId] [Onboarding] SKIP → $displayName : Previous errors" `
            -Level "WARN" -LogFile $LogFile
        return $PipelineObject
    }

    # Retry configurations
    $retryConfig = @{
        WaitForEntra          = @{ MaxRetries = 10; DelaySeconds = 30 }
        AddToGroup            = @{ MaxRetries = 3; DelaySeconds = 5  }
        AddToDistributionList = @{ MaxRetries = 2; DelaySeconds = 3  }
        AssignLicense         = @{ MaxRetries = 4; DelaySeconds = 5  }
    }


    foreach ($actionItem in $PipelineObject.Plan) {
        $action = $actionItem.Action
        $target = $actionItem.Target

        # Initialize result
        $actionItem.Result = $null

        if (-not $retryConfig.ContainsKey($action)) {
            Add-PipelineError -PipelineObject $PipelineObject `
                              -Step $action `
                              -Message "Unknown action: $action" `
                              -LogFile $LogFile

            Write-Log -Message "[$correlationId] [Onboarding] $action -> $target : FAILED (unknown action)" `
                -Level "ERROR" -LogFile $LogFile

            return $PipelineObject
        }

        $retryParams  = $retryConfig[$action]
        $attempt = 0
        $success = $false

        while (-not $success -and $attempt -lt $retryParams.MaxRetries) {
            $attempt++
            try {
                # Call action function
                $result = switch ($action) {
                    "WaitForEntra" { Wait-ForEntraUser -Identity $PipelineObject.Identity -LogFile $LogFile }
                    "AddToGroup" { Add-OnboardingGroupMember -Identity $PipelineObject.Identity -Target $target -LogFile $LogFile }
                    "AddToDistributionList" { Add-OnboardingDLMember -Identity $PipelineObject.Identity -Target $target -LogFile $LogFile }
                    "AssignLicense" { Set-OnboardingLicense -Identity $PipelineObject.Identity -Config $Config -LogFile $LogFile }
                }

                # Results for reporting
                $actionItem.Result = switch ($result) {
                    "Added"          { "Added to $target" }
                    "AlreadyExists"  { "Already in $target" }
                    "AlreadyAssigned"{ "Already assigned $target" }
                    "Found"          { "User found" }
                    default          { $result }
                }

                $success = $true

                # Single-line log per action
                $logStatus = $actionItem.Result
                Write-Log -Message "[$correlationId] [Onboarding] $action -> $target : $logStatus" `
                          -Level "INFO" -LogFile $LogFile
            }
            catch {
                # Retry logging
                if ($attempt -lt $retryParams.MaxRetries) {
                    Write-Log -Message "[$correlationId] [Onboarding] $action -> $target : RETRY ($attempt)" `
                        -Level "WARN" -LogFile $LogFile
                    $delay = ($retryParams.DelaySeconds * $attempt) + (Get-Random -Minimum 1 -Maximum 3)
                    Start-Sleep -Seconds $delay
                } else {
                    # All retries exhausted → mark structured pipeline error
                    Add-PipelineError -PipelineObject $PipelineObject `
                                    -Step $action `
                                    -Message "Failed during $action → $target" `
                                    -Exception $_.Exception `
                                    -LogFile $LogFile

                    $actionItem.Result = "Failed"
                    Write-Log -Message "[$correlationId] [Onboarding] $action -> $target : FAILED" `
                        -Level "ERROR" -LogFile $LogFile
                }
            }
        }

        # Abort if WaitForEntra failed all retries
        if ($action -eq "WaitForEntra" -and -not $success) {
            Write-Log -Message "[$correlationId] [Onboarding] WaitForEntra -> $displayName : FAILED (not found)" `
                -Level "ERROR" -LogFile $LogFile
            
            return $PipelineObject
        }
    }

    if ($PipelineObject.Errors.Count -gt 0) {
        $PipelineObject.Status = "Failed"
    }

    return $PipelineObject
}