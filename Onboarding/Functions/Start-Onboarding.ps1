function Start-Onboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$LogFile,
        [PSCustomObject]$PipelineObject,
        [PSCustomObject]$Config
    )  

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -ne "Valid") {
        Write-Log -Message "[SKIP] Skipping execution for $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName) due to validation errors: $($PipelineObject.Errors -join ', ')" -Level "WARN" -LogFile $LogFile
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
        Write-Log -Message "[ERROR] Failed to query AD for $($id.DisplayName): $($_.Exception.Message)" -Level "ERROR" -LogFile $LogFile
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
        SyncToEntra           = @{ MaxRetries = 3; DelaySeconds = 10 }
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
                    "CreateUser"            { New-OnboardingUser -Identity $id -PipelineObject $PipelineObject -Exist $exist -LogFile $LogFile }
                    "SyncToEntra"  { Invoke-EntraSync -Config $Config -LogFile $LogFile }
                    "WaitForEntra" { Wait-ForEntraUser -Identity $id -LogFile $LogFile }
                    "AddToGroup"            { Add-OnboardingGroupMember -Identity $id -Target $target -LogFile $LogFile }
                    "AddToDistributionList" { Add-OnboardingDLMember -Identity $id -Target $target -LogFile $LogFile }
                    "AssignLicense"         { Set-OnboardingLicense -Identity $id -Config $Config -LogFile $LogFile }
                    default                 { throw "Unknown action: $action" }
                }
                $success = $true
            }
            catch {
                Write-Log -Message "[RETRY] $action attempt $attempt failed: $($_.Exception.Message)" -Level "WARN" -LogFile $LogFile
                if ($attempt -lt $retryParams.MaxRetries) {
                    Start-Sleep -Seconds ($retryParams.DelaySeconds * $attempt)
                } else {
                    Write-Log -Message "`t[ERROR] $action failed for $($id.DisplayName): $($_.Exception.Message)" -Level "ERROR" -LogFile $LogFile
                    $PipelineObject.Errors += "$action failed"
                }
            }
        }
    }

    if ($PipelineObject.Errors.Count -gt 0) {
        $PipelineObject.Status = "Failed"
    }

    return $PipelineObject
}