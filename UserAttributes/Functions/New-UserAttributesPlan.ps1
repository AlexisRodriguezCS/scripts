function New-UserAttributesPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "New-UserAttributesPlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        if ($PipelineObject.Status -ne "Valid") { return }

        # Action: one SetAttribute per value that is actually different
        $PipelineObject.Plan = @(Get-UserAttributeChanges -Current $PipelineObject.Identity.Current -Desired $PipelineObject.Raw.Changes)

        if ($PipelineObject.Plan.Count -eq 0) {
            $PipelineObject.Status = "NoChange"
        }

        # Log planned actions with before -> after
        foreach ($item in $PipelineObject.Plan) {
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] SetAttribute -> $($item.Target): '$($item.Old)' -> '$($item.Value)' : PENDING" `
              -Level "INFO" -LogFile $LogFile
        }
    }
}
