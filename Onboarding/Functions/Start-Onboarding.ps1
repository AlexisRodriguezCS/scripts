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

    $correlationId = $PipelineObject.CorrelationId
    $displayName   = $PipelineObject.Identity.DisplayName

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -in @("Skipped","Failed")) {
        Write-Log -Message "[$correlationId] [Start-Onboarding] SKIP: $displayName due to previous errors: $($PipelineObject.Errors -join ', ')" `
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

        if (-not $retryConfig.ContainsKey($action)) {
            Write-Log -Message "[$correlationId] [Start-Onboarding] ERROR: Unknown action '$action'" `
                -Level "ERROR" -LogFile $LogFile

            $PipelineObject.Errors.Add("Unknown action: $action")
            $PipelineObject.Status = "Failed"
            return $PipelineObject
        }

        $retryParams  = $retryConfig[$action]
        $attempt = 0
        $success = $false

        Write-Log -Message "[$correlationId] [Start-Onboarding] ACTION: $action → $target" `
            -Level "INFO" -LogFile $LogFile

        while (-not $success -and $attempt -lt $retryParams.MaxRetries) {
            $attempt++
            try {
                switch ($action) {
                    "WaitForEntra" { Wait-ForEntraUser -Identity $PipelineObject.Identity -LogFile $LogFile }
                    "AddToGroup"            { Add-OnboardingGroupMember -Identity $PipelineObject.Identity -Target $target -LogFile $LogFile }
                    "AddToDistributionList" { Add-OnboardingDLMember -Identity $PipelineObject.Identity -Target $target -LogFile $LogFile }
                    "AssignLicense"         { Set-OnboardingLicense -Identity $PipelineObject.Identity -Config $Config -LogFile $LogFile }
                    default                 { throw "Unknown action: $action" }
                }
                $success = $true
                Write-Log -Message "[$correlationId] [Start-Onboarding] SUCCESS: $action → $target" `
                    -Level "INFO" -LogFile $LogFile
            }
            catch {
                Write-Log -Message "[$correlationId] [Start-Onboarding] RETRY: $action attempt $attempt failed: $($_.Exception.Message)" `
                    -Level "WARN" -LogFile $LogFile
                if ($attempt -lt $retryParams.MaxRetries) {
                    $delay = ($retryParams.DelaySeconds * $attempt) + (Get-Random -Minimum 1 -Maximum 3)
                    Start-Sleep -Seconds $delay
                } else {
                    Write-Log -Message "[$correlationId] [Start-Onboarding] ERROR: $action failed permanently for $displayName" `
                        -Level "ERROR" -LogFile $LogFile

                    $PipelineObject.Errors.Add("$action failed: $($_.Exception.Message)")
                }
            }
        }

        # Abort if WaitForEntra failed all retries
        if ($action -eq "WaitForEntra" -and -not $success) {
            Write-Log -Message "[$correlationId] [Start-Onboarding] ABORT: User never appeared in Entra ($displayName)" `
                -Level "ERROR" -LogFile $LogFile

            $PipelineObject.Status = "Failed"
            return $PipelineObject
        }
    }

    if ($PipelineObject.Errors.Count -gt 0) {
        $PipelineObject.Status = "Failed"
    }

    return $PipelineObject
}