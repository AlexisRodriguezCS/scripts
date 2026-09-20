function Rename-UserAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Kept before the change, so the log can say what it was and not just what it is
    $previousName = "$($Identity.Current.DisplayName)"
    if (-not $previousName) { $previousName = "$($Identity.Current.GivenName) $($Identity.Current.Surname)".Trim() }

    # First name, last name and what everyone sees in Outlook
    Set-ADUser -Identity $Identity.DistinguishedName `
               -GivenName $Identity.FirstName `
               -Surname $Identity.LastName `
               -DisplayName $Identity.DisplayName `
               -ErrorAction Stop

    # The AD object's own name (the CN part of the DN). Skipped when it already matches,
    # so re-running is safe, and done last because it changes the DN every other step used.
    $currentCn = ($Identity.DistinguishedName -split '(?<!\\),')[0] -replace '^CN='
    if ($currentCn -cne $Identity.DisplayName) {
        Rename-ADObject -Identity $Identity.DistinguishedName -NewName $Identity.DisplayName -ErrorAction Stop

        # Everything after this has to use the new DN
        $Identity.DistinguishedName = $Identity.DistinguishedName -replace '^CN=[^,]+', "CN=$($Identity.DisplayName)"
    }

    if ($previousName -and $previousName -cne $Identity.DisplayName) {
        return "$previousName is now $($Identity.DisplayName)"
    }
    return "Renamed to $($Identity.DisplayName)"
}
