function New-NameChangePlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "New-NameChangePlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        if ($PipelineObject.Status -ne "Valid") { return }

        $identity = $PipelineObject.Identity
        $current  = $identity.Current
        $plan     = @()

        # Action: the name itself (first, last, display name and the AD object name)
        if ($identity.FirstName -cne $current.GivenName -or
            $identity.LastName  -cne $current.Surname   -or
            $identity.DisplayName -cne "$($current.DisplayName)") {
            $plan += @{ Action = "RenameAccount"; Target = $identity.DisplayName; Result = $null }
        }

        # Action: sign-in name. Optional on purpose: changing it breaks saved passwords,
        # mapped drives and anything that stored the old username, so it is only done when asked.
        if ($identity.NewSamAccountName -ne $identity.SamAccountName) {
            $plan += @{ Action = "ChangeLogonName"; Target = $identity.NewSamAccountName; Result = $null }
        }

        # Action: email. The new address becomes primary; the old one stays as an alias so
        # mail sent to it still arrives (unless the request said not to keep it).
        if ($identity.NewSamAccountName -ne $identity.SamAccountName) {
            $plan += @{ Action = "UpdateEmail"; Target = $identity.NewUpn; Result = $null }
        }

        # Action: push it to Microsoft 365 now instead of waiting for the next sync cycle
        if ($plan.Count) {
            $plan += @{ Action = "SyncToEntra"; Target = $identity.NewUpn; Result = $null }
        }

        $PipelineObject.Plan = $plan

        if (-not $plan.Count) {
            $PipelineObject.Status = "NoChange"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($identity.SamAccountName) : nothing to change" `
                      -Level "INFO" -LogFile $LogFile
            return
        }

        foreach ($item in $plan) {
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($item.Action) -> $($item.Target) : PENDING" `
                      -Level "INFO" -LogFile $LogFile
        }
    }
}
