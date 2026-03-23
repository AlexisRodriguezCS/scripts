function Add-OnboardingDLMember {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Check if user is already a member of the distribution list
    $isMember = (Get-DistributionGroupMember -Identity $Target -ErrorAction Stop | 
                 Where-Object { $_.Alias -eq $Identity.EntraUPN })

    if ($isMember) {
        Write-Log -Message "`tAddToDistributionList  : Already in $Target, skipping" -Level "INFO" -LogFile $LogFile
        return
    }

    # Add user to distribution list
    Add-DistributionGroupMember -Identity $Target -Member $Identity.EntraUPN -ErrorAction Stop

    Write-Log -Message "`tAddToDistributionList  : Added $($Identity.DisplayName) to $Target" -Level "INFO" -LogFile $LogFile
}