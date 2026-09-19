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

        # Check if user already exists in AD before attempting creation
        try {
            $exist = $null -ne (Get-ADUser -Filter "SamAccountName -eq '$($Identity.SamAccountName)'" -ErrorAction Stop)
        }
        catch {
            throw "AD lookup failed: $($_.Exception.Message)"
        }

        # Skips creating a user so it goes to next action
        if ($exist) {
            $PipelineObject.Status = "AlreadyExists"
            Write-Log -Message "[$($PipelineObject.CorrelationId.Substring(0,8))] [$stepName] CreateUser -> $($Identity.SamAccountName) : ALREADY_EXISTS" `
                    -Level "INFO" -LogFile $LogFile
            return
        }

        # Generate temp password
        $plainPassword  = New-RandomPassword
        $securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

        try {
            New-ADUser `
            -Name $Identity.DisplayName `
            -GivenName $Identity.FirstName `
            -Surname $Identity.LastName `
            -SamAccountName $Identity.SamAccountName `
            -UserPrincipalName $Identity.UserPrincipalName `
            -Path $Identity.OU `
            -AccountPassword $securePassword `
            -ChangePasswordAtLogon $true `
            -Enabled $true
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