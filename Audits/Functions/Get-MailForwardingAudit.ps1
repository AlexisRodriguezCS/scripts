function Get-MailForwardingAudit {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    # Anything outside our own domains is external
    $ourDomains = @(Get-AcceptedDomain -ErrorAction Stop | ForEach-Object { "$($_.DomainName)".ToLower() })

    function Test-External([string]$address) {
        $domain = ($address -split '@')[-1].ToLower()
        return $domain -and $domain -notin $ourDomains
    }

    $mailboxes = Get-Mailbox -ResultSize Unlimited -ErrorAction Stop

    foreach ($mailbox in $mailboxes) {
        $name = $mailbox.PrimarySmtpAddress

        # Mailbox-level forwarding (set by an admin or the user in OWA)
        if ($mailbox.ForwardingSmtpAddress) {
            $target   = "$($mailbox.ForwardingSmtpAddress)" -replace '^smtp:'
            $external = Test-External $target
            New-AuditFinding -Check "MailForwarding" -Name $name -Detail "Mailbox forwards to $target" `
                             -Flagged $external -Reason $(if ($external) { "Forwards all mail outside the company" })
        }

        # Inbox rules that forward or redirect.
        # ponytail: one call per mailbox, slow on large tenants; switch to the Exchange admin audit log if it takes too long
        $rules = Get-InboxRule -Mailbox $name -ErrorAction SilentlyContinue |
                 Where-Object { $_.Enabled -and ($_.ForwardTo -or $_.RedirectTo -or $_.ForwardAsAttachmentTo) }

        foreach ($rule in $rules) {
            # Values look like: "John" [SMTP:john@example.com]
            $targets = @($rule.ForwardTo) + @($rule.RedirectTo) + @($rule.ForwardAsAttachmentTo) |
                       ForEach-Object { if ("$_" -match 'SMTP:([^\]]+)') { $Matches[1] } } | Where-Object { $_ }
            $external = @($targets | Where-Object { Test-External $_ })

            New-AuditFinding -Check "MailForwarding" -Name $name -Detail "Inbox rule '$($rule.Name)' -> $($targets -join ', ')" `
                             -Flagged ($external.Count -gt 0) -Reason $(if ($external) { "Inbox rule forwards outside the company" })
        }
    }
}
