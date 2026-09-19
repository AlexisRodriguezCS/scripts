function Get-ExternalSharingAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [string]$LogFile
    )

    $check      = "ExternalSharing"
    $maxAgeDays = if ($Config.ExternalUserMaxAgeDays) { $Config.ExternalUserMaxAgeDays } else { 365 }
    $allowed    = @($Config.AllowedSharingDomains)

    # --- Sites: how far sharing is allowed to go ---
    # Sites with sharing off are fine, so only the ones that allow it are reported.
    $sites = @(Get-PnPTenantSite -IncludeOneDriveSites -ErrorAction Stop |
               Where-Object { "$($_.SharingCapability)" -ne "Disabled" })

    foreach ($site in $sites) {
        $capability = "$($site.SharingCapability)"
        $name       = "$($site.Url)"

        # "ExternalUserAndGuestSharing" = Anyone links: a link that opens the file with no sign-in at all
        $anyoneLinks = $capability -eq "ExternalUserAndGuestSharing"

        New-AuditFinding -Check $check -Name $name -Detail "Sharing: $capability" -Flagged $anyoneLinks `
                         -Reason $(if ($anyoneLinks) { "Anyone with the link can open files here without signing in; switch the site to guest sharing only" })
    }

    # --- Guests: who outside the company holds access ---
    $now   = Get-Date
    $pageSize = 50
    $position = 0
    $guests = @()

    # One page at a time, until a short page comes back (the tenant can hold thousands)
    do {
        $page = @(Get-PnPExternalUser -PageSize $pageSize -Position $position -ErrorAction Stop)
        $guests += $page
        $position += $pageSize
    } while ($page.Count -eq $pageSize)

    foreach ($guest in $guests) {
        $email  = "$($guest.AcceptedAs)"
        $domain = $email.Split("@")[-1]
        $age    = if ($guest.WhenCreated) { [int]($now - [datetime]$guest.WhenCreated).TotalDays } else { 0 }

        $reason = if ($allowed.Count -and $domain -notin $allowed) {
            "$domain isn't on the approved sharing list"
        }
        elseif ($age -gt $maxAgeDays) {
            "Invited $age days ago and never reviewed; remove them if the project is over"
        }

        New-AuditFinding -Check $check -Name $email -Detail "Guest, invited $age days ago" -Flagged ([bool]$reason) -Reason $reason
    }
}
