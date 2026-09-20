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

        # HR writes the manager as a full name ("Mary Johnson") or a username; AD stores a DN.
        # A manager that can't be matched doesn't block the account: the new hire still needs to
        # work on day one, so it's logged as a warning and the account is created without one.
        $managerDn = $null
        if ($raw.Manager) {
            $search = $raw.Manager -replace "'", "\'"   # names like O'Brien would break the filter
            $found  = @(Get-ADUser -Filter "SamAccountName -eq '$search' -or DisplayName -eq '$search'" -ErrorAction SilentlyContinue)

            if ($found.Count -eq 1) {
                $managerDn = $found[0].DistinguishedName
            } else {
                # 0 = nobody by that name, 2+ = two people share it and picking one would be a guess
                $why = if ($found.Count -eq 0) { "NOT_FOUND" } else { "$($found.Count) people match that name" }
                Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] Manager -> $($raw.Manager) : $why, account created without a manager" `
                          -Level "WARN" -LogFile $LogFile
            }
        }

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
            # HR fills these in on the request; without them the org chart, Outlook details
            # and the access review (which groups people by manager) are all empty
            Title             = $raw.Title
            Department        = $raw.Department
            ManagerDN         = $managerDn
            Office            = $raw.Location
            Company           = $Config.Company
        }

        # Log identity information
        $id = $PipelineObject.CorrelationId.Substring(0,8)
        $identity = $PipelineObject.Identity

        Write-Log -Message "[$id] [$stepName] SamAccountName -> $($identity.SamAccountName) : GENERATED" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "[$id] [$stepName] UPN -> $($identity.UserPrincipalName) : GENERATED" -Level "INFO" -LogFile $LogFile
        Write-Log -Message "[$id] [$stepName] OU -> $($identity.OU) : GENERATED" -Level "INFO" -LogFile $LogFile
    }
}