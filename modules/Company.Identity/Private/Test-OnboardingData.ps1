function Test-OnboardingData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$PipelineObject
    )

    $raw = $PipelineObject.Raw

    # Define fields to check
    $fields = @{
        FirstName  = "FirstName"
        LastName   = "LastName"
        Title      = "Title"
        Department = "Department"
        Role       = "Role"
    }

    # Loop through each field and validate
    foreach ($field in $fields.Keys) {
        
        # Check if these fields are empty, null, or just spaces.
        if ([string]::IsNullOrWhiteSpace($raw.$field)) {
            $PipelineObject.Errors += "$($fields[$field]) is missing"
        }
    }

    # Log success if no errors or log warnings if there are errors
    if ($PipelineObject.Errors.Count -eq 0) {
        Write-LogAndVerbose -Message "[PASS] Validation passed for $($raw.FirstName) $($raw.LastName)" -Level "INFO"
        $PipelineObject.Status = "Valid"
    } else {
        Write-LogAndVerbose -Message "[FAIL] Validation failed for $($raw.FirstName) $($raw.LastName): $($PipelineObject.Errors -join ', ')" -Level "WARN"
        $PipelineObject.Status = "Skipped"
    }

    return $PipelineObject
}
