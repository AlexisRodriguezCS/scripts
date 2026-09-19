function Remove-OffboardingGroupMember {
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
        Remove-ADGroupMember -Identity $Target -Members $Identity.DistinguishedName -Confirm:$false -ErrorAction Stop
        return "Removed"
    }
    catch {
        # Already removed on a previous run
        if ($_.Exception.Message -like "*not a member*") {
            return "NotMember"
        }
        throw
    }
}
