function Get-OffboardingCheck {
    [CmdletBinding()]
    param(
        # CSV of leavers from HR (SamAccountName column)
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [string]$LogFile
    )

    foreach ($row in Import-Csv -Path $Path) {
        $sam = "$($row.SamAccountName)".Trim()
        if (-not $sam) { continue }

        $adUser = Get-ADUser -Filter "SamAccountName -eq '$($sam -replace "'", "''")'" -Properties Enabled, MemberOf -ErrorAction Stop

        if (-not $adUser) {
            New-AuditFinding -Check "OffboardingCheck" -Name $sam -Detail "Not in AD (already deleted)"
            continue
        }

        # Everything that should be true after offboarding
        $problems = @()
        if ($adUser.Enabled)                { $problems += "Account still enabled" }
        if (@($adUser.MemberOf).Count -gt 0) { $problems += "Still in $(@($adUser.MemberOf).Count) groups" }

        $mgUser = Get-MgUser -UserId "$sam@$($Config.TenantDomain)" -Property "assignedLicenses" -ErrorAction SilentlyContinue
        if ($mgUser.AssignedLicenses) { $problems += "Still has $(@($mgUser.AssignedLicenses).Count) license(s)" }

        New-AuditFinding -Check "OffboardingCheck" -Name $sam `
                         -Detail $(if ($problems) { $problems -join "; " } else { "Fully offboarded" }) `
                         -Flagged ($problems.Count -gt 0) -Reason ($problems -join "; ")
    }
}
