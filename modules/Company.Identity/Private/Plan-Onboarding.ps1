function Plan-Onboarding {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject
    )  

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -ne "Valid") {
        Write-LogAndVerbose -Message "[SKIP] Skipping onboarding for $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName) due to validation errors: $($PipelineObject.Errors -join ', ')" -Level "WARN"
        return $PipelineObject
    }

    # Initialize onboarding plan
    $PipelineObject.Plan = @()

    # Get raw data
    $raw = $PipelineObject.Raw

    # Action: Create user account
    $PipelineObject.Plan += @{
        Action = "CreateUser"
        Target = "$($raw.FirstName) $($raw.LastName)"
    }

    # Action: Add to AD groups
    if ($raw.ADGroups) {
        foreach ($group in $raw.ADGroups -split ';') {
            $PipelineObject.Plan += @{
                Action = "AddToGroup"
                Target = $group
            }
        }
    }

    # Action: Add to distribution lists
    if ($raw.DistributionList) {
        foreach ($dist in $raw.DistributionList -split ';') {
            $PipelineObject.Plan += @{
                Action = "AddToDistributionList"
                Target = $dist
            }
        }
    }

    # Action: Assign license
    if ($raw.License) {
        $PipelineObject.Plan += @{
            Action = "AssignLicense"
            Target = $raw.License
        }
    }   
    
    # Log planned actions
    foreach ($item in $PipelineObject.Plan) {
        Write-LogAndVerbose -Message "$([char]9)[PLAN] $($item.Action): $($item.Target)" -Level "INFO"
    }

    return $PipelineObject
}