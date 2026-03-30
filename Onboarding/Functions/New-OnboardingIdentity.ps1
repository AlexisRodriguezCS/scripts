function New-OnboardingIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config
    )

    $stepName = "New-OnboardingIdentity"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)

        # Only proceed if validation passed
        if ($PipelineObject.Status -ne "Valid") {
            Write-Log -Message "[SKIP] Identity build skipped due to validation state: $($PipelineObject.Status)" `
                      -Level "WARN" -LogFile $LogFile
            return
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
            UserPrincipalName = "$username$($Config.UPNSuffix)"  # on-prem AD UPN
            EntraUPN          = "$username@$($Config.TenantDomain)" # Entra/M365 UPN
            OU                = $ou
        } 

        # Log identity information
        Write-Log -Message "[BUILD] $($PipelineObject.Identity.DisplayName)" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "`tSamAccountName    : $($PipelineObject.Identity.SamAccountName)" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "`tUPN               : $($PipelineObject.Identity.UserPrincipalName)" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "`tOU                : $($PipelineObject.Identity.OU)" -Level "INFO" -LogFile $LogFile
    }
}