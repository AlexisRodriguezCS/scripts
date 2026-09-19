function Invoke-Request {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Fields,

        # Configs: Onboarding (new hire, role change, update info), Offboarding (leaver), Requests (queue)
        [Parameter(Mandatory)]
        [hashtable]$Configs,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [bool]$Apply
    )

    $type = "$($Fields.RequestType)".Trim()
    $row  = ConvertTo-RequestRow -Fields $Fields
    $preview = if ($Apply) { "" } else { "[Preview, nothing changed] " }

    # Run the right script, then turn its result into one plain-English line for HR
    switch ($type) {
        "New hire" {
            $result = Invoke-UserOnboarding -Rows @($row) -Config $Configs.Onboarding -LogFile $LogFile -Apply $Apply
            $user   = $result.Users[0]

            # Temp password goes to IT by email, never into the SharePoint list
            foreach ($credential in $result.Credentials) {
                Send-MgUserMail -UserId $Configs.Requests.SenderMailbox -ErrorAction Stop -BodyParameter @{
                    Message = @{
                        Subject      = "Sign-in details: $($credential.Name)"
                        Body         = @{ ContentType = "Text"; Content = (@(
                            "Username: $($credential.Username)"
                            if ($credential.TemporaryAccessPass) { "Temporary Access Pass (day one sign-in code): $($credential.TemporaryAccessPass)" }
                            if ($credential.TempPassword) { "Temporary password: $($credential.TempPassword) (must be changed at first sign-in)" }
                        ) -join "`n") }
                        ToRecipients = @(@{ EmailAddress = @{ Address = $Configs.Requests.TempPasswordRecipient } })
                    }
                    SaveToSentItems = $false
                }
            }

            switch ($user.Status) {
                "Created"       { @{ Ok = $true;  Message = "${preview}Account created: $($user.Username). IT has the temporary password." } }
                "AlreadyExists" { @{ Ok = $true;  Message = "${preview}Account already existed: $($user.Username). Access was checked and fixed if needed." } }
                "Valid"         { @{ Ok = $true;  Message = "${preview}Ready to create $($row.FirstName) $($row.LastName)." } }
                default         { @{ Ok = $false; Message = "Needs attention: $($user.Errors)" } }
            }
        }
        "Role change" {
            $result = Invoke-UserMover -Requests @($row) -Config $Configs.Onboarding -LogFile $LogFile -Apply $Apply
            $user   = $result.Users[0]
            switch ($user.Status) {
                "Moved"  { @{ Ok = $true;  Message = "${preview}Role change done for $($row.SamAccountName): $($row.Title), $($row.Department)." } }
                "Valid"  { @{ Ok = $true;  Message = "${preview}Ready to update $($row.SamAccountName)." } }
                default  { @{ Ok = $false; Message = "Needs attention ($($user.Status)): $($user.Errors)" } }
            }
        }
        "Leaver" {
            $result = Invoke-UserOffboarding -Rows @($row) -Config $Configs.Offboarding -LogFile $LogFile -Apply $Apply
            $user   = $result.Users[0]
            switch ($user.Status) {
                "Offboarded" { @{ Ok = $true;  Message = "${preview}$($row.SamAccountName) has been offboarded." + $(if ($row.Manager) { " $($row.Manager) now has their mailbox and OneDrive." } else { "" }) } }
                "Valid"      { @{ Ok = $true;  Message = "${preview}Ready to offboard $($row.SamAccountName)." } }
                "NotFound"   { @{ Ok = $false; Message = "Needs attention: no account found with username $($row.SamAccountName)." } }
                default      { @{ Ok = $false; Message = "Needs attention: $($user.Errors)" } }
            }
        }
        "Update info" {
            $result = Invoke-UserAttributesUpdate -Requests @($row) -Config $Configs.Onboarding -LogFile $LogFile -Apply $Apply
            $user   = $result.Users[0]
            switch ($user.Status) {
                "Updated"  { @{ Ok = $true;  Message = "${preview}Updated $($row.SamAccountName): $($user.Changes)" } }
                "NoChange" { @{ Ok = $true;  Message = "Nothing to change, $($row.SamAccountName) already has these details." } }
                "Valid"    { @{ Ok = $true;  Message = "${preview}Would change: $($user.Changes)" } }
                default    { @{ Ok = $false; Message = "Needs attention ($($user.Status)): $($user.Errors)" } }
            }
        }
        # Help desk requests: small, so they return their own plain-English result
        "Unlock account" { Invoke-AccountUnlock -SamAccountName $row.SamAccountName -Config $Configs.Requests -Apply $Apply }
        "Reset password" { Invoke-PasswordReset -SamAccountName $row.SamAccountName -Config $Configs.Requests -Apply $Apply }
        "Group access"   { Invoke-GroupAccessRequest -SamAccountName $row.SamAccountName -Group $row.Group -Change $row.Change -Config $Configs.Requests -Apply $Apply }
    }
}
