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
        return "Added"
    }
    catch {
        if ($_.Exception.Message -like "*already a member*") {
            return "AlreadyExists"
        }
        throw
    }
}