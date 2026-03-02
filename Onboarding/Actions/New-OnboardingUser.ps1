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

    if ($Exist) {
        Write-Log -Message "`tCreateUser             : Already exists, skipping" -Level "INFO" -LogFile $LogFile
        return
    }

    New-ADUser `
        -Name $Identity.DisplayName `
        -GivenName $Identity.FirstName `
        -Surname $Identity.LastName `
        -SamAccountName $Identity.SamAccountName `
        -UserPrincipalName $Identity.UserPrincipalName `
        -Path $Identity.OU `
        -Enabled $true

    $PipelineObject.Status = "Created"
    Write-Log -Message "`tCreateUser             : Created $($Identity.DisplayName)" -Level "INFO" -LogFile $LogFile
}