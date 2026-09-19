function New-InactiveAccountPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "New-InactiveAccountPlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        if ($PipelineObject.Status -ne "Inactive") { return }

        $raw = $PipelineObject.Raw

        # Members are disabled (reversible); guests are removed (recoverable for 30 days)
        $action = if ($raw.UserType -eq "Guest") { "RemoveGuest" } else { "DisableAccount" }
        $PipelineObject.Plan = @(@{ Action = $action; Target = $raw.UPN; Result = $null })

        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] $($PipelineObject.Plan[0].Action) -> $($raw.UPN) : PENDING ($($raw.Reason))" `
                  -Level "INFO" -LogFile $LogFile
    }
}
