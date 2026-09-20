function New-OnboardingUser {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Random temp password, shown once, must change at first logon')]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $stepName = "New-OnboardingUser"

    Invoke-PipelineStep -PipelineObject $PipelineObject -StepName $stepName -LogFile $LogFile -StepAction {
        param($PipelineObject, $LogFile)
        
        $Identity = $PipelineObject.Identity
        $id       = $PipelineObject.CorrelationId.Substring(0,8)
        $baseName = $Identity.SamAccountName

        # Find a free username. An existing account is only treated as "this person" when the Employee ID matches;
        # a different John Smith gets johnsmith2 instead of the old John Smith's account.
        for ($n = 1; $n -le 99; $n++) {
            $suffix    = if ($n -eq 1) { "" } else { "$n" }
            $candidate = $baseName.Substring(0, [math]::Min($baseName.Length, 20 - $suffix.Length)).TrimEnd('.') + $suffix

            try {
                $existing = Get-ADUser -Filter "SamAccountName -eq '$candidate'" -Properties EmployeeID -ErrorAction Stop
            }
            catch {
                throw "AD lookup failed: $($_.Exception.Message)"
            }

            if (-not $existing) { break }

            # Same person (re-run): nothing to create, continue with the rest of the plan
            if ($Identity.EmployeeID -and $existing.EmployeeID -eq $Identity.EmployeeID) {
                $Identity.SamAccountName = $candidate
                $PipelineObject.Status = "AlreadyExists"
                Write-Log -Message "[$id] [$stepName] CreateUser -> $candidate : ALREADY_EXISTS (Employee ID $($Identity.EmployeeID))" `
                        -Level "INFO" -LogFile $LogFile
                return
            }

            # Without an Employee ID we can't tell a re-run from a different person, so don't guess
            if (-not $Identity.EmployeeID) {
                throw "Username $candidate is already taken and no EmployeeID was given to confirm it's the same person"
            }

            Write-Log -Message "[$id] [$stepName] CreateUser -> $candidate : TAKEN by a different person, trying next" -Level "INFO" -LogFile $LogFile
        }

        # Update the identity if we had to pick another username
        if ($candidate -ne $baseName) {
            $Identity.SamAccountName    = $candidate
            $Identity.UserPrincipalName = $candidate + ($Identity.UserPrincipalName -replace '^[^@]+')
            $Identity.EntraUPN          = $candidate + ($Identity.EntraUPN -replace '^[^@]+')
            $Identity.DisplayName       = "$($Identity.DisplayName) ($candidate)"   # AD names must be unique in an OU
        }

        # Generate temp password
        $plainPassword  = New-RandomPassword
        $securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

        $newUser = @{
            Name                  = $Identity.DisplayName
            GivenName             = $Identity.FirstName
            Surname               = $Identity.LastName
            SamAccountName        = $Identity.SamAccountName
            UserPrincipalName     = $Identity.UserPrincipalName
            Path                  = $Identity.OU
            AccountPassword       = $securePassword
            ChangePasswordAtLogon = $true
            Enabled               = $true
        }
        # Stored so re-runs can recognise this person
        if ($Identity.EmployeeID) { $newUser.EmployeeID = $Identity.EmployeeID }

        # Who they are and who they report to; skipped when HR left the field blank
        # (AD rejects an empty value, so only what was filled in is sent)
        foreach ($attribute in "Title", "Department", "Office", "Company") {
            if ($Identity.$attribute) { $newUser[$attribute] = $Identity.$attribute }
        }
        if ($Identity.ManagerDN) { $newUser.Manager = $Identity.ManagerDN }

        try {
            New-ADUser @newUser -ErrorAction Stop
        }
        catch {
            throw "User creation failed: $($_.Exception.Message)"
        }

        $PipelineObject.Status = "Created"
        # Kept in memory only (never logged or reported); shown once at the end of the run
        $PipelineObject | Add-Member -NotePropertyName TempPassword -NotePropertyValue $plainPassword -Force
        Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] CreateUser -> $($Identity.SamAccountName) : CREATED" `
            -Level "INFO" -LogFile $LogFile
    }
}