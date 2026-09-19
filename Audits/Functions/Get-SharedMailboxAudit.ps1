function Get-SharedMailboxAudit {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    $mailboxes = @(Get-Mailbox -RecipientTypeDetails SharedMailbox -ResultSize Unlimited -ErrorAction Stop)

    # Whether an account is disabled, looked up once per person
    $disabled = @{}
    function Test-Disabled([string]$who) {
        if (-not $disabled.ContainsKey($who)) {
            $disabled[$who] = [bool](Get-User -Identity $who -ErrorAction SilentlyContinue).AccountDisabled
        }
        $disabled[$who]
    }

    foreach ($mailbox in $mailboxes) {
        $name = "$($mailbox.PrimarySmtpAddress)"

        # A shared mailbox has a password-less account; if sign-in isn't blocked, someone could log in to it directly
        $account = Get-User -Identity $name -ErrorAction SilentlyContinue
        if ($account -and -not $account.AccountDisabled) {
            New-AuditFinding -Check "SharedMailboxes" -Name $name -Detail "Sign-in allowed" -Flagged $true `
                             -Reason "Sign-in isn't blocked on this shared mailbox; block it so nobody can log in to it directly"
        }

        # Who can read it (FullAccess) and send as it (SendAs); skip the built-in SELF and inherited admin rights
        $access = @(Get-MailboxPermission -Identity $name -ErrorAction SilentlyContinue |
                    Where-Object { -not $_.IsInherited -and "$($_.User)" -notlike "NT AUTHORITY\*" -and "$($_.AccessRights)" -match "FullAccess" } |
                    ForEach-Object { [pscustomobject]@{ Who = "$($_.User)"; Right = "FullAccess" } })
        $access += @(Get-RecipientPermission -Identity $name -ErrorAction SilentlyContinue |
                     Where-Object { "$($_.Trustee)" -notlike "NT AUTHORITY\*" } |
                     ForEach-Object { [pscustomobject]@{ Who = "$($_.Trustee)"; Right = "SendAs" } })

        if ($access.Count -eq 0) {
            New-AuditFinding -Check "SharedMailboxes" -Name $name -Detail "Nobody has access" -Flagged $true `
                             -Reason "Nobody can open this shared mailbox: remove it or give it an owner"
        }

        foreach ($entry in $access) {
            $gone = Test-Disabled $entry.Who
            New-AuditFinding -Check "SharedMailboxes" -Name $name -Detail "$($entry.Right): $($entry.Who)" `
                             -Flagged $gone -Reason $(if ($gone) { "$($entry.Who) is disabled but still has $($entry.Right): remove it" })
        }
    }
}
