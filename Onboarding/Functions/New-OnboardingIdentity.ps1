function New-OnboardingIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$LogFile,
        [PSCustomObject]$Config,
        [PSCustomObject]$PipelineObject
    )

    # Skip processing if there are errors from previous steps
    if ($PipelineObject.Status -ne "Valid") {
        Write-Log -Message "[SKIP] Skipping data build for $($PipelineObject.Raw.FirstName) $($PipelineObject.Raw.LastName) due to validation errors: $($PipelineObject.Errors -join ', ')" -Level "WARN" -LogFile $LogFile
        return $PipelineObject
    }

    # Get raw data
    $raw = $PipelineObject.Raw

    # Generate username based on config format
    $username = switch ($Config.UsernameFormat) {
        "FirstLast"        { "$($raw.FirstName.ToLower())$($raw.LastName.ToLower())" }
        "FirstDotLast"     { "$($raw.FirstName.ToLower()).$($raw.LastName.ToLower())" }
        default            { "$($raw.FirstName.ToLower())$($raw.LastName.ToLower())" }
    }

    # Set OU based on department
    $ou = "OU=$($raw.Department),$($Config.DefaultOU)"

    # Store Identity object
    $PipelineObject.Identity = [PSCustomObject]@{
        FirstName         = $raw.FirstName
        LastName          = $raw.LastName
        DisplayName       = "$($raw.FirstName) $($raw.LastName)"
        SamAccountName    = $username
        UserPrincipalName = "$username@$($Config.Domain)"
        OU                = $ou
    } 

    # Log identity information
    Write-Log -Message "[BUILD] $($PipelineObject.Identity.DisplayName)" -Level "INFO" -LogFile $LogFile
    Write-Log -Message "`tSamAccountName    : $($PipelineObject.Identity.SamAccountName)" -Level "INFO" -LogFile $LogFile
    Write-Log -Message "`tUPN               : $($PipelineObject.Identity.UserPrincipalName)" -Level "INFO" -LogFile $LogFile
    Write-Log -Message "`tOU                : $($PipelineObject.Identity.OU)" -Level "INFO" -LogFile $LogFile

    return $PipelineObject
}