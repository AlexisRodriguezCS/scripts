function Test-UserAttributesData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "Test-UserAttributesData"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        $raw = $PipelineObject.Raw

        # sAMAccountName: required, max 20 chars, none of the characters AD rejects
        if ($raw.SamAccountName -notmatch '^[^"/\\\[\]:;|=,+*?<>@'' ]{1,20}$') {
            $PipelineObject.Errors.Add("SamAccountName is missing or invalid")
        }

        if ($raw.Changes.Count -eq 0) {
            $PipelineObject.Errors.Add("No attributes to change")
        }

        foreach ($attribute in @($raw.Changes.Keys)) {
            $value = "$($raw.Changes[$attribute])".Trim()
            $raw.Changes[$attribute] = $value

            if ($attribute -notin $script:ManagedUserAttributes) {
                $PipelineObject.Errors.Add("$attribute is not a managed attribute")
            }
            elseif ([string]::IsNullOrWhiteSpace($value)) {
                $PipelineObject.Errors.Add("$attribute is empty")
            }
            elseif ($value.Length -gt 128) {
                $PipelineObject.Errors.Add("$attribute is longer than 128 characters")
            }
        }

        # Manager is passed as a SamAccountName and resolved to a DN later
        if ($raw.Changes.ContainsKey("Manager") -and $raw.Changes.Manager -notmatch '^[^"/\\\[\]:;|=,+*?<>@'' ]{1,20}$') {
            $PipelineObject.Errors.Add("Manager must be a SamAccountName")
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
