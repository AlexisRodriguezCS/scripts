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
            Result = $null
        }


        # Action: Add to AD groups
        if ($raw.ADGroups) {
            foreach ($group in $raw.ADGroups -split ';') {
                $PipelineObject.Plan += @{
                    Action = "AddToGroup"
                    Target = $group
                    Result = $null
                }
            }
        }

        # Action: Add to distribution lists
        if ($raw.DistributionList) {
            foreach ($dist in $raw.DistributionList -split ';') {
                $PipelineObject.Plan += @{
                    Action = "AddToDistributionList"
                    Target = $dist
                    Result = $null
                }
            }
        }

        # Action: Assign license
        if ($raw.License) {
            $PipelineObject.Plan += @{
                Action = "AssignLicense"
                Target = $raw.License
                Result = $null
            }
        }   
    
        # Log planned actions
        foreach ($item in $PipelineObject.Plan) {
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($item.Action) -> $($item.Target) : PENDING" `
              -Level "INFO" -LogFile $LogFile
        }
    }
}