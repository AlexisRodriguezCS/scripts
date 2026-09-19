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

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepArgs @($Config) -StepAction {
        param($PipelineObject, $LogFile, $Config)

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

        # Strip characters AD rejects (spaces, apostrophes, hyphens, accents) and enforce the 20-char sAMAccountName limit
        $username = $username -replace '[^a-z0-9.]', ''
        if ($username.Length -gt 20) { $username = $username.Substring(0, 20).TrimEnd('.') }

        # Set OU based on department
        $ou = "OU=$($raw.Department),$($Config.DefaultOU)"

        # Store Identity object
        $PipelineObject.Identity = [PSCustomObject]@{
            FirstName         = $raw.FirstName
            LastName          = $raw.LastName
            DisplayName       = "$($raw.FirstName) $($raw.LastName)"
            SamAccountName    = $username
            UserPrincipalName = "$username$($Config.UPNSuffix)"  # on-prem AD UPN
            EntraUPN          = Resolve-EntraUpn -SamAccountName $username -AdUpn "$username$($Config.UPNSuffix)" -Config $Config # Entra/M365 UPN
            OU                = $ou
            EmployeeID        = $raw.EmployeeID
        } 

        # Log identity information
        $id = $PipelineObject.CorrelationId.Substring(0,8)
        $identity = $PipelineObject.Identity

        Write-Log -Message "[$id] [$stepName] SamAccountName -> $($identity.SamAccountName) : GENERATED" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "[$id] [$stepName] UPN -> $($identity.UserPrincipalName) : GENERATED" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "[$id] [$stepName] OU -> $($identity.OU) : GENERATED" -Level "INFO" -LogFile $LogFile
    }
}