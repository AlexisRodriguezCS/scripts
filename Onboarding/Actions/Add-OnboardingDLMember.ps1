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

    try {
        Add-DistributionGroupMember -Identity $Target -Member $Identity.EntraUPN -ErrorAction Stop
        Write-Log -Message "`tAddToDistributionList  : Added $($Identity.DisplayName) to $Target" -Level "INFO" -LogFile $LogFile
    }
    catch {
        if ($_.Exception.Message -like "*already a member*") {
            Write-Log -Message "`tAddToDistributionList  : Already in $Target, skipping" -Level "INFO" -LogFile $LogFile
            return
        }
        throw
    }
}