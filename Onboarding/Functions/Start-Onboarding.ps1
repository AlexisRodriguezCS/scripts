function Start-Onboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,
        [PSCustomObject]$PipelineObject,
        [PSCustomObject]$Config
    )  

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -eq "Skipped" -or $PipelineObject.Status -eq "Failed") {
        Write-Log -Message "[SKIP] Skipping execution for $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName) due to validation errors: $($PipelineObject.Errors -join ', ')" -Level "WARN" -LogFile $LogFile
        return $PipelineObject
    }

    # Retry configurations for different action types
    $retryConfig = @{
        WaitForEntra          = @{ MaxRetries = 10; DelaySeconds = 30 }
        AddToGroup            = @{ MaxRetries = 3; DelaySeconds = 5  }
        AddToDistributionList = @{ MaxRetries = 2; DelaySeconds = 3  }
        AssignLicense         = @{ MaxRetries = 4; DelaySeconds = 5  }
    }


    foreach ($actionItem in $PipelineObject.Plan) {
        $action = $actionItem.Action
        $target = $actionItem.Target
        $retryParams  = $retryConfig[$action]
        $attempt = 0
        $success = $false

        while (-not $success -and $attempt -lt $retryParams.MaxRetries) {
            $attempt++
            try {
                switch ($action) {
                    "WaitForEntra" { Wait-ForEntraUser -Identity $PipelineObject.Identity -Config $Config -LogFile $LogFile }
                    "AddToGroup"            { Add-OnboardingGroupMember -Identity $PipelineObject.Identity -Target $target -LogFile $LogFile }
                    "AddToDistributionList" { Add-OnboardingDLMember -Identity $PipelineObject.Identity -Target $target -LogFile $LogFile }
                    "AssignLicense"         { Set-OnboardingLicense -Identity $PipelineObject.Identity -Config $Config -LogFile $LogFile }
                    default                 { throw "Unknown action: $action" }
                }
                $success = $true
            }
            catch {
                Write-Log -Message "[RETRY] $action attempt $attempt failed: $($_.Exception.Message)" -Level "WARN" -LogFile $LogFile
                if ($attempt -lt $retryParams.MaxRetries) {
                    Start-Sleep -Seconds ($retryParams.DelaySeconds * $attempt)
                } else {
                    Write-Log -Message "`t[ERROR] $action failed for $($PipelineObject.Identity.DisplayName): $($_.Exception.Message)" -Level "ERROR" -LogFile $LogFile
                    $PipelineObject.Errors += "$action failed"
                }
            }
        }

        # Abort if WaitForEntra failed all retries
        if ($action -eq "WaitForEntra" -and -not $success) {
            Write-Log -Message "`t[ABORT] User never appeared in Entra for $($PipelineObject.Identity.DisplayName)" -Level "ERROR" -LogFile $LogFile
            $PipelineObject.Status = "Failed"
            return $PipelineObject
        }
    }

    if ($PipelineObject.Errors.Count -gt 0) {
        $PipelineObject.Status = "Failed"
    }

    return $PipelineObject
}