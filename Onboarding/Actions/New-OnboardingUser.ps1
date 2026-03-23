function New-OnboardingUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [PSCustomObject]$PipelineObject,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [bool]$Exist = $false
    )

    # Skips creating a user so it goes to next action
    if ($Exist) {
        Write-Log -Message "`tCreateUser             : Already exists, skipping" -Level "INFO" -LogFile $LogFile
        return
    }

    # Generate temp password
    $plainPassword  = "Welcome@$(Get-Date -Format 'yyyy')!"
    $securePassword = ConvertTo-SecureString $plainPassword -AsPlainText -Force

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
    
    # Clear plain text from memory
    $plainPassword = $null

    $PipelineObject.Status = "Created"
    Write-Log -Message "`tCreateUser             : Created $($Identity.DisplayName)" -Level "INFO" -LogFile $LogFile
}