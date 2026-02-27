function Start-Onboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject
    )  

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -ne "Valid") {
        Write-LogAndVerbose -Message "[SKIP] Skipping execution for $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName) due to validation errors: $($PipelineObject.Errors -join ', ')" -Level "WARN"
        return $PipelineObject
    }

    # Get identity details
    $id = $PipelineObject.Identity

    # Check if user already exists in AD before attempting creation
    try {
        $exist = $null -ne (Get-ADUser -Filter "SamAccountName -eq '$($id.SamAccountName)'" -ErrorAction Stop)
    }
    catch {
        # Log AD query failure
        Write-LogAndVerbose -Message "[ERROR] Failed to query AD for $($id.DisplayName): $($_.Exception.Message)" -Level "ERROR"
        $PipelineObject.Errors += "AD pre-check failed"
        $PipelineObject.Status = "Failed"
        return $PipelineObject
    }

    # If user existed before run, mark as AlreadyExists and skip creation
    if ($exist) {
        $PipelineObject.Status = "AlreadyExists"
    }

    # Retry configurations for different action types
    $retryConfig = @{
        CreateUser            = @{ MaxRetries = 5; DelaySeconds = 10 }
        AddToGroup            = @{ MaxRetries = 3; DelaySeconds = 5  }
        AddToDistributionList = @{ MaxRetries = 2; DelaySeconds = 3  }
        AssignLicense         = @{ MaxRetries = 4; DelaySeconds = 5  }
    }


    foreach ($actionItem in $PipelineObject.Plan) {
        $action = $actionItem.Action
        $target = $actionItem.Target
        $config = $retryConfig[$action]

        try {
            Invoke-WithRetry -MaxRetries $config.MaxRetries `
                             -DelaySeconds $config.DelaySeconds `
                             -Action  {
                switch ($action) {
                    "NewOnboardingUser"        { New-OnboardingUser -Identity $id -PipelineObject $PipelineObject -Exist $exist }
                    "AddOnboardingGroupMember" { Add-OnboardingGroupMember -Identity $id -Target $target }
                    "AddOnboardingDLMember"    { Add-OnboardingDLMember -Identity $id -Target $target }
                    "SetOnboardingLicense"     { Set-OnboardingLicense -Identity $id -Target $target }
                    default                    { throw "Unknown action: $action" }
                }
            }
        }
        catch {
            # Final failure after retries
            Write-LogAndVerbose -Message "`t[ERROR] $action failed for $($id.DisplayName): $($_.Exception.Message)" -Level "ERROR"
            $PipelineObject.Errors += "$action failed"
        }
    }

    if ($PipelineObject.Errors.Count -gt 0) {
        $PipelineObject.Status = "Failed"
    }

    return $PipelineObject
}