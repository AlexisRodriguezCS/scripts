function Get-UserAttributeChanges {
    [CmdletBinding()]
    param(
        # Current AD user (from Get-ADUser with the managed attributes loaded)
        [Parameter(Mandatory)]
        [PSCustomObject]$Current,

        # Requested values; only the keys that are present are compared
        [Parameter(Mandatory)]
        [hashtable]$Desired
    )

    # One plan item per attribute that actually changes; unchanged values are skipped (idempotent)
    foreach ($attribute in $script:ManagedUserAttributes) {
        if (-not $Desired.ContainsKey($attribute)) { continue }

        $old = "$($Current.$attribute)"
        $new = "$($Desired[$attribute])"

        # Case-sensitive so a casing fix ("it" -> "IT") still counts as a change
        if ($old -cne $new) {
            @{ Action = "SetAttribute"; Target = $attribute; Value = $new; Old = $old; Result = $null }
        }
    }
}
