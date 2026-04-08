function Test-OnboardingData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "Test-OnboardingData"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)
        
        $raw = $PipelineObject.Raw

        # Define fields to check
        $fields = @("FirstName","LastName","Title","Department","Role")

        # Loop through each field and validate
        foreach ($field in $fields) {
            # Check if these fields are empty, null, or just spaces.
            if ([string]::IsNullOrWhiteSpace($raw.$field)) {
                $PipelineObject.Errors.Add("$field is missing")
            }
        }

        # Log success if no errors or log warnings if there are errors
        if ($PipelineObject.Errors.Count -eq 0) {
            $PipelineObject.Status = "Valid"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$StepName] Validation -> $($raw.FirstName) $($raw.LastName): Valid" `
                      -Level "INFO" -LogFile $LogFile
        } else {
            $PipelineObject.Status = "Skipped"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$StepName] Validation -> $($raw.FirstName) $($raw.LastName): Skipped $($PipelineObject.Errors -join ', ')" `
                      -Level "WARN" -LogFile $LogFile
        }
    }
}
