function Build-Onboarding {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject
    )

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -ne "Valid") {
        Write-LogAndVerbose -Message "[SKIP] Skipping data build for $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName) due to validation errors: $($PipelineObject.Errors -join ', ')" -Level "WARN"
        return $PipelineObject
    }

    # Get raw data
    $raw = $PipelineObject.Raw

    # Generate samAccountName (firstName.LastName)
    $sam = "$($raw.FirstName.ToLower()).$($raw.LastName.ToLower())"

    # Generate email address (firstName.LastName@dev.com)
    $upn = "$sam@dev.com"

    # Generate display name (FirstName LastName)
    $displayName = "$($raw.FirstName) $($raw.LastName)"

    # Set OU based on department
    $ou = "OU=$($raw.Department),OU=Users,DC=dev,DC=com"

    # Store Identity object
    $PipelineObject.Identity = @{
        samAccountName = $sam
        UserPrincipalName = $upn
        DisplayName = $displayName
        OU = $ou
    }  

    # Log identity information
    foreach ($prop in $PipelineObject.Identity.Keys) {
        $value = $PipelineObject.Identity[$prop]
        Write-LogAndVerbose -Message ("`t[BUILD] {0}: {1}" -f $prop, $value) -Level "INFO"
    }
    return $PipelineObject
}