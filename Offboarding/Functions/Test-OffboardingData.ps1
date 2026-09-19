function Test-OffboardingData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "Test-OffboardingData"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        $raw = $PipelineObject.Raw

        # sAMAccountName: required, max 20 chars, none of the characters AD rejects
        if ([string]::IsNullOrWhiteSpace($raw.SamAccountName)) {
            $PipelineObject.Errors.Add("SamAccountName is missing")
        }
        elseif ($raw.SamAccountName -notmatch '^[^"/\\\[\]:;|=,+*?<>@'' ]{1,20}$') {
            $PipelineObject.Errors.Add("SamAccountName is invalid")
        }

        # Manager is optional but must look like a UPN
        if ($raw.Manager -and $raw.Manager -notmatch '^[^@\s]+@[^@\s]+$') {
            $PipelineObject.Errors.Add("Manager is not a valid UPN")
        }

        # Log success if no errors or log warnings if there are errors
        if ($PipelineObject.Errors.Count -eq 0) {
            $PipelineObject.Status = "Valid"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] Validation -> $($raw.SamAccountName): Valid" `
                      -Level "INFO" -LogFile $LogFile
        } else {
            $PipelineObject.Status = "Invalid"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] Validation -> $($raw.SamAccountName): Invalid $($PipelineObject.Errors -join ', ')" `
                      -Level "WARN" -LogFile $LogFile
        }
    }
}
