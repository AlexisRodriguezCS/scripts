function Move-OffboardingUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$Target,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Move user to the disabled OU
    Move-ADObject -Identity $Identity.DistinguishedName -TargetPath $Target -ErrorAction Stop
    return "Moved"
}
