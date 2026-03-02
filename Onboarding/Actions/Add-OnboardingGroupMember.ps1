function Add-OnboardingGroupMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Check if user is already a member of the group
    $isMember = (Get-ADGroupMember -Identity $Target -ErrorAction Stop | 
                 Where-Object { $_.SamAccountName -eq $Identity.SamAccountName })

    if ($isMember) {
        Write-Log -Message "`tAddToGroup             : Already in $Target, skipping" -Level "INFO" -LogFile $LogFile
        return
    }

    # Add user to AD group
    Add-ADGroupMember -Identity $Target -Members $Identity.SamAccountName -ErrorAction Stop

    Write-Log -Message "`tAddToGroup             : Added $($Identity.DisplayName) to $Target" -Level "INFO" -LogFile $LogFile
}