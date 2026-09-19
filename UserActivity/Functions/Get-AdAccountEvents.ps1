function Get-AdAccountEvents {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string]$SamAccountName,
        [Parameter(Mandatory)] [datetime]$Since,

        # Domain controller whose Security log records lockouts (the PDC emulator); empty = skip
        [string]$LockoutServer
    )

    $user = Get-ADUser -Identity $SamAccountName -ErrorAction Stop -Properties `
        Enabled, LockedOut, AccountLockoutTime, PasswordLastSet, PasswordExpired, LastBadPasswordAttempt, badPwdCount, lastLogonTimestamp, "msDS-UserPasswordExpiryTimeComputed"

    $state = [pscustomobject]@{
        Enabled        = $user.Enabled
        LockedOut      = $user.LockedOut
        LockoutTime    = $user.AccountLockoutTime
        PasswordSet    = $user.PasswordLastSet
        PasswordExpired = $user.PasswordExpired
        PasswordExpires = $(if ($user."msDS-UserPasswordExpiryTimeComputed" -and $user."msDS-UserPasswordExpiryTimeComputed" -ne [long]::MaxValue) { [datetime]::FromFileTime($user."msDS-UserPasswordExpiryTimeComputed") })
        BadPasswords   = $user.badPwdCount
        LockoutSources = @()
    }

    $events = @()
    if ($user.PasswordLastSet -and $user.PasswordLastSet -ge $Since) {
        $events += New-ActivityEvent -Time $user.PasswordLastSet -Source "AD" -Event "Password set (AD)" -Detail "By the user, an admin, or a synced self-service reset"
    }
    if ($user.LastBadPasswordAttempt -and $user.LastBadPasswordAttempt -ge $Since) {
        $events += New-ActivityEvent -Time $user.LastBadPasswordAttempt -Source "AD" -Event "Wrong password (AD)" -Detail "Bad password count: $($user.badPwdCount) (as seen by one domain controller)" -Result "Failure"
    }
    if ($user.LockedOut -and $user.AccountLockoutTime) {
        $events += New-ActivityEvent -Time $user.AccountLockoutTime -Source "AD" -Event "Locked out (AD)" -Detail "Still locked right now" -Result "Failure"
    }
    if ($user.lastLogonTimestamp) {
        $last = [datetime]::FromFileTime($user.lastLogonTimestamp)
        if ($last -ge $Since) { $events += New-ActivityEvent -Time $last -Source "AD" -Event "Last AD logon (approximate, can lag up to 14 days)" -Result "Success" }
    }

    # Which computer/device caused each lockout (event 4740 on the PDC). Needs Event Log Readers on that DC.
    if ($LockoutServer) {
        try {
            $lockouts = Get-WinEvent -ComputerName $LockoutServer -ErrorAction Stop -FilterHashtable @{ LogName = "Security"; Id = 4740; StartTime = $Since } |
                        Where-Object { "$($_.Properties[0].Value)" -eq $SamAccountName }
            foreach ($lockout in $lockouts) {
                $source = "$($lockout.Properties[1].Value)"
                $state.LockoutSources += $source
                $events += New-ActivityEvent -Time $lockout.TimeCreated -Source "Lockout" -Event "Locked out by $source" `
                                             -Detail "That computer/device sent the wrong password (often an old saved password)" -Result "Failure"
            }
        }
        catch {
            $events += New-ActivityEvent -Time (Get-Date) -Source "Lockout" -Event "Couldn't read lockout events from $LockoutServer" -Detail $_.Exception.Message
        }
    }

    [pscustomobject]@{ State = $state; Events = $events }
}
