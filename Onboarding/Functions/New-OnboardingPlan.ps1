function New-OnboardingPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        # Optional: turns on extras like the Temporary Access Pass
        [PSCustomObject]$Config = [pscustomobject]@{}
    )

    $stepName = "New-OnboardingPlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

        # Initialize onboarding plan
        $PipelineObject.Plan = @()

        # Get raw data
        $raw = $PipelineObject.Raw

        # "OnPrem" clients have no Microsoft 365: no sync to wait for, no mailbox, no license.
        # Anything else (the default) has a tenant, so the cloud steps are planned.
        $hasCloud = "$($Config.Environment)" -ne "OnPrem"

        # Action: Wait for Entra sync
        if ($hasCloud) {
            $PipelineObject.Plan += @{
                Action = "WaitForEntra"
                Target = "$($raw.FirstName) $($raw.LastName)"
                Result = $null
            }
        }

        # Action: One-time sign-in code for day one (passwordless setup), if the client uses it
        if ($hasCloud -and $Config.UseTemporaryAccessPass) {
            $PipelineObject.Plan += @{
                Action = "CreateAccessPass"
                Target = "$($raw.FirstName) $($raw.LastName)"
                Result = $null
            }
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

        # Action: Assign license (before DLs: the mailbox only exists once licensed)
        if ($hasCloud -and $raw.License) {
            $PipelineObject.Plan += @{
                Action = "AssignLicense"
                Target = $raw.License
                Result = $null
            }
        }

        # Action: Add to distribution lists (these live in Exchange Online, not AD)
        if ($hasCloud -and $raw.DistributionList) {
            foreach ($dist in $raw.DistributionList -split ';') {
                $PipelineObject.Plan += @{
                    Action = "AddToDistributionList"
                    Target = $dist
                    Result = $null
                }
            }
        }

        # Log planned actions
        foreach ($item in $PipelineObject.Plan) {
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($item.Action) -> $($item.Target) : PENDING" `
              -Level "INFO" -LogFile $LogFile
        }
    }
}