function Invoke-GroupAccessRequest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$SamAccountName,
        [Parameter(Mandatory)] [string]$Group,
        [Parameter(Mandatory)] [ValidateSet("Add", "Remove")] [string]$Change,
        [Parameter(Mandatory)] [PSCustomObject]$Config,
        [bool]$Apply
    )

    # Only groups IT has approved for self-service; a request can never grant admin or sensitive access
    if ($Group -notin @($Config.RequestableGroups)) {
        return @{ Ok = $false; Message = "Needs attention: '$Group' can't be requested through this list. Ask IT directly." }
    }

    $lookup = Get-RequestUser -SamAccountName $SamAccountName -Config $Config
    if ($lookup.Problem) { return @{ Ok = $false; Message = "Needs attention: $($lookup.Problem)" } }

    $isMember = @(Get-ADGroupMember -Identity $Group -ErrorAction Stop | Where-Object { $_.SamAccountName -eq $SamAccountName }).Count -gt 0

    # Already the way it was asked for: nothing to do (safe to re-run)
    if ($Change -eq "Add" -and $isMember)        { return @{ Ok = $true; Message = "$SamAccountName is already in $Group." } }
    if ($Change -eq "Remove" -and -not $isMember) { return @{ Ok = $true; Message = "$SamAccountName wasn't in $Group." } }

    if (-not $Apply) { return @{ Ok = $true; Message = "[Preview, nothing changed] Would $($Change.ToLower()) $SamAccountName $(if ($Change -eq 'Add') { 'to' } else { 'from' }) $Group." } }

    if ($Change -eq "Add") {
        Add-ADGroupMember -Identity $Group -Members $lookup.User.DistinguishedName -ErrorAction Stop
        return @{ Ok = $true; Message = "Added $SamAccountName to $Group. It can take up to an hour to show up everywhere." }
    }

    Remove-ADGroupMember -Identity $Group -Members $lookup.User.DistinguishedName -Confirm:$false -ErrorAction Stop
    return @{ Ok = $true; Message = "Removed $SamAccountName from $Group." }
}
