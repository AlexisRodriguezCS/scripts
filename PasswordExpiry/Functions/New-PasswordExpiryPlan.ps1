function New-PasswordExpiryPlan {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "New-PasswordExpiryPlan"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        if ($PipelineObject.Status -ne "Due") { return }

        # Action: send reminder email
        $PipelineObject.Plan = @(@{ Action = "SendReminder"; Target = $PipelineObject.Raw.Mail; Result = $null })

        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] SendReminder -> $($PipelineObject.Raw.Mail) : PENDING" `
                  -Level "INFO" -LogFile $LogFile
    }
}
