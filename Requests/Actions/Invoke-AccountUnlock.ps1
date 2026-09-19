function Invoke-AccountUnlock {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$SamAccountName,
        [Parameter(Mandatory)] [PSCustomObject]$Config,
        [bool]$Apply
    )

    $lookup = Get-RequestUser -SamAccountName $SamAccountName -Config $Config
    if ($lookup.Problem) { return @{ Ok = $false; Message = "Needs attention: $($lookup.Problem)" } }

    if (-not $lookup.User.LockedOut) {
        return @{ Ok = $true; Message = "$SamAccountName wasn't locked out. If they still can't sign in, a password reset may be needed." }
    }

    if (-not $Apply) { return @{ Ok = $true; Message = "[Preview, nothing changed] Would unlock $SamAccountName." } }

    Unlock-ADAccount -Identity $lookup.User.DistinguishedName -ErrorAction Stop
    return @{ Ok = $true; Message = "Unlocked $SamAccountName. They can sign in again with their current password." }
}
