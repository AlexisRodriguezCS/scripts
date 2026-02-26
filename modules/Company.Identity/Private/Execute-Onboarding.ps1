function Execute-Onboarding {
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

    # Get raw data
    $raw = $PipelineObject.Raw
    $id = $PipelineObject.Identity

    # Retry configurations for different action types
    $retryConfig = @{
        CreateUser            = @{ MaxRetries = 5; Delay = 10 }
        AddToGroup            = @{ MaxRetries = 3; Delay = 5  }
        AddToDistributionList = @{ MaxRetries = 2; Delay = 3  }
        AssignLicense         = @{ MaxRetries = 4; Delay = 5  }
    }


    foreach ($actionItem in $PipelineObject.Plan) {
        $action = $actionItem.Action
        $target = $actionItem.Target
        $config = $retryConfig[$action]
        $actionFailed = $false

        try {
            Invoke-WithRetry -MaxRetries $cfg.MaxRetries `
                             -RetryDelaySeconds $cfg.Delay `
                             -Action  {
                switch ($action) {
                    # ------------------------
                    # CREATE USER
                    # ------------------------
                    "CreateUser" {
                        # Check if user already exists in AD
                        $exist = Get-ADUser -Filter "SamAccountName -eq '$($id.SamAccountName)'" -ErrorAction SilentlyContinue

                        # Log and skip if user already exists
                        if ($exist) {
                            Write-LogAndVerbose -Message "`t[EXECUTE] User already exists: $($id.DisplayName)" -Level "INFO"
                            return
                        } 

                        # Create new AD user
                        New-ADUser `
                            -Name $id.DisplayName `
                            -GivenName $id.FirstName `
                            -Surname $id.LastName `
                            -SamAccountName $id.SamAccountName `
                            -UserPrincipalName $id.UserPrincipalName `
                            -Path $id.OU `
                            -Enabled $true
                    }
                    # ------------------------
                    # ADD TO GROUP 
                    # ------------------------
                    "AddToGroup" {
                        # Replace with actual AD group check
                        Write-LogAndVerbose -Message "`t[EXECUTE] Added to group: $target" -Level "INFO"
                    }
                    # ------------------------
                    # ADD TO DL
                    # ------------------------
                    "AddToDistributionList" {
                        # Replace with actual Exchange check
                        Write-LogAndVerbose -Message "`t[EXECUTE] Added to DL: $target" -Level "INFO"
                    }
                    # ------------------------
                    # ASSIGN LICENSE
                    # ------------------------
                    "AssignLicense" {
                        # Replace with actual MSOL / Graph check
                        Write-LogAndVerbose -Message "`t[EXECUTE] Assigned license: $target" -Level "INFO"
                    }
                    default {
                        throw "Unknown action: $action"
                    }
                }
            } 
        }
        catch {
            # Final failure after retries
            Write-LogAndVerbose -Message "`t[ERROR] $action failed for $($id.DisplayName): $($_.Exception.Message)" -Level "ERROR"
            $PipelineObject.Errors += "$action failed"
            $actionFailed = $true
        }
    }

    if ($PipelineObject.Errors.Count -eq 0) {
        $PipelineObject.Status = "Created"
    } else {
        $PipelineObject.Status = "Failed"
    }

    return $PipelineObject
}