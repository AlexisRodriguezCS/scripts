function Get-ActivitySummary {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Events,

        # AD account state (can be $null for cloud-only users)
        [PSCustomObject]$State,

        [int]$Days = 14
    )

    # Plain-English answers to "why can't this person work?", most important first
    $summary  = @()
    $signIns  = @($Events | Where-Object Source -eq "Sign-in")
    $failures = @($signIns | Where-Object Result -eq "Failure")

    function Get-Sources($list) {
        @($list | ForEach-Object {
            $app    = if ($_.Detail -match 'App: ([^|]+)') { $Matches[1].Trim() }
            $device = if ($_.Detail -match 'Device: ([^|]+)') { $Matches[1].Trim() }
            (@($app, $device) | Where-Object { $_ }) -join " on "
        } | Group-Object | Sort-Object Count -Descending | ForEach-Object { "$($_.Name) ($($_.Count)x)" })
    }

    # 1. Account state right now
    if ($State) {
        if (-not $State.Enabled) { $summary += "The account is DISABLED in AD." }
        if ($State.LockedOut) {
            $by = if ($State.LockoutSources) { " Lockout came from: $(@($State.LockoutSources | Sort-Object -Unique) -join ', ')." } else { "" }
            $summary += "The account is LOCKED OUT right now (since $($State.LockoutTime)).$by"
        }
        if ($State.PasswordExpired) { $summary += "The password has EXPIRED. They need to change it (self-service reset or IT)." }
        elseif ($State.PasswordExpires -and $State.PasswordExpires -lt (Get-Date).AddDays(3)) {
            $summary += "The password expires soon: $($State.PasswordExpires)."
        }
    }

    # 2. The classic: password changed, but something still uses the old one
    $passwordEvents = @($Events | Where-Object { $_.Source -in @("Entra audit", "AD") -and $_.Event -match "password" -and $_.Event -notmatch "FAILED" } |
                        Sort-Object Time -Descending)
    $oldPasswordCodes = @(50126, 50053, 50133, 50173)

    if ($passwordEvents) {
        $change = $passwordEvents[0]
        $after  = @($failures | Where-Object { $_.Time -gt $change.Time -and $_.ErrorCode -in $oldPasswordCodes })

        if ($after.Count) {
            $summary += "Password was changed on $($change.Time) ($($change.Event)). Since then $($after.Count) sign-in(s) failed with the old password, from: $((Get-Sources $after) -join '; '). " +
                        "Something is still using the old password (phone mail app, Outlook, saved Wi-Fi/VPN or mapped drive): update it there."
        } else {
            $summary += "Password was changed on $($change.Time) ($($change.Event)). No wrong-password sign-ins since."
        }
    }
    else {
        $wrong = @($failures | Where-Object ErrorCode -in $oldPasswordCodes)
        if ($wrong.Count) { $summary += "$($wrong.Count) wrong-password sign-in(s), from: $((Get-Sources $wrong) -join '; ')." }
    }

    # 3. Other blockers
    $blocked = @($failures | Where-Object ErrorCode -eq 53003)
    if ($blocked.Count) {
        # Policy name is in brackets at the end of the event text
        $policies = @($blocked | ForEach-Object { if ($_.Event -match '\(([^()]+)\)$') { $Matches[1] } } | Sort-Object -Unique)
        $summary += "Blocked by Conditional Access $($blocked.Count) time(s): $($policies -join ', ')."
    }

    $mfa = @($failures | Where-Object ErrorCode -eq 500121)
    if ($mfa.Count) { $summary += "MFA not completed $($mfa.Count) time(s): check their Authenticator app / phone number." }

    # 4. Is it working at all?
    $lastOk = $signIns | Where-Object Result -eq "Success" | Sort-Object Time -Descending | Select-Object -First 1
    if ($lastOk) {
        $summary += "Last successful sign-in: $($lastOk.Time) ($(if ($lastOk.Detail -match 'App: ([^|]+)') { $Matches[1].Trim() }))."
    } elseif ($signIns) {
        $summary += "No successful sign-in in the last $Days days."
    } else {
        $summary += "No sign-in attempts at all in the last $Days days (not even failed ones)."
    }

    return $summary
}
