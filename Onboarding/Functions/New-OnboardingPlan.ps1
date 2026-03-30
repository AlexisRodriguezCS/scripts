function New-OnboardingPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )  

    $stepName = "New-OnboardingPlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        # Initialize onboarding plan
        $PipelineObject.Plan = @()

        # Get raw data
        $raw = $PipelineObject.Raw

        # Action: Wait for Entra sync
        $PipelineObject.Plan += @{
            Action = "WaitForEntra"
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
        Write-Log -Message "[PLAN] $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName)" -Level "INFO" -LogFile $LogFile
        foreach ($item in $PipelineObject.Plan) {
            Write-Log -Message "`t$($item.Action.PadRight(24)): $($item.Target)" -Level "INFO" -LogFile $LogFile
        }
    }
}