Describe "Help desk requests" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Requests -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Requests\Requests.psm1" -Force

        $Config = [pscustomobject]@{
            RequestableGroups = @("GRP-Printers", "GRP-VPN")
            SenderMailbox = "automation@corp.com"; TempPasswordRecipient = "it@corp.com"
        }
    }

    BeforeEach {
        Mock Get-ADUser {
            switch -Wildcard ($Filter) {
                "*'locked'*" { [pscustomobject]@{ SamAccountName = "locked"; DistinguishedName = "CN=locked"; LockedOut = $true;  DisplayName = "Locked User" } }
                "*'jdoe'*"   { [pscustomobject]@{ SamAccountName = "jdoe";   DistinguishedName = "CN=jdoe";   LockedOut = $false; DisplayName = "Jane Doe" } }
                "*'admin'*"  { [pscustomobject]@{ SamAccountName = "admin";  DistinguishedName = "CN=admin";  LockedOut = $true;  adminCount = 1 } }
            }
        } -ModuleName Requests
        Mock Unlock-ADAccount {} -ModuleName Requests
        Mock Set-ADAccountPassword {} -ModuleName Requests
        Mock Set-ADUser {} -ModuleName Requests
        Mock Send-MgUserMail {} -ModuleName Requests
        Mock Add-ADGroupMember {} -ModuleName Requests
        Mock Remove-ADGroupMember {} -ModuleName Requests
    }

    Context "Unlock account" {

        It "unlocks a locked-out user" {
            $r = Invoke-AccountUnlock -SamAccountName "locked" -Config $Config -Apply $true
            $r.Ok | Should -BeTrue
            Should -Invoke Unlock-ADAccount -ModuleName Requests -Times 1 -Exactly
        }

        It "explains when the user wasn't locked" {
            $r = Invoke-AccountUnlock -SamAccountName "jdoe" -Config $Config -Apply $true
            $r.Message | Should -Match "wasn't locked out"
            Should -Invoke Unlock-ADAccount -ModuleName Requests -Times 0 -Exactly
        }

        It "refuses admin accounts" {
            $r = Invoke-AccountUnlock -SamAccountName "admin" -Config $Config -Apply $true
            $r.Ok      | Should -BeFalse
            $r.Message | Should -Match "Protected account"
        }

        It "refuses unknown users" {
            (Invoke-AccountUnlock -SamAccountName "ghost" -Config $Config -Apply $true).Message | Should -Match "No account found"
        }
    }

    Context "Reset password" {

        It "resets, forces a change at sign-in, and emails IT (not the list)" {
            $r = Invoke-PasswordReset -SamAccountName "jdoe" -Config $Config -Apply $true

            $r.Ok      | Should -BeTrue
            $r.Message | Should -Not -Match "Temporary password:"
            Should -Invoke Set-ADUser -ModuleName Requests -Times 1 -Exactly -ParameterFilter { $ChangePasswordAtLogon -eq $true }
            Should -Invoke Send-MgUserMail -ModuleName Requests -Times 1 -Exactly -ParameterFilter {
                $BodyParameter.Message.ToRecipients[0].EmailAddress.Address -eq "it@corp.com"
            }
        }

        It "changes nothing in a preview" {
            $null = Invoke-PasswordReset -SamAccountName "jdoe" -Config $Config -Apply $false
            Should -Invoke Set-ADAccountPassword -ModuleName Requests -Times 0 -Exactly
        }
    }

    Context "Group access" {

        It "refuses groups that aren't on the allowlist" {
            $r = Invoke-GroupAccessRequest -SamAccountName "jdoe" -Group "Domain Admins" -Change "Add" -Config $Config -Apply $true
            $r.Ok | Should -BeFalse
            Should -Invoke Add-ADGroupMember -ModuleName Requests -Times 0 -Exactly
        }

        It "adds someone to an allowed group" {
            Mock Get-ADGroupMember { } -ModuleName Requests
            $r = Invoke-GroupAccessRequest -SamAccountName "jdoe" -Group "GRP-VPN" -Change "Add" -Config $Config -Apply $true
            $r.Message | Should -Match "Added jdoe to GRP-VPN"
        }

        It "does nothing when they're already in it" {
            Mock Get-ADGroupMember { [pscustomobject]@{ SamAccountName = "jdoe" } } -ModuleName Requests
            $r = Invoke-GroupAccessRequest -SamAccountName "jdoe" -Group "GRP-VPN" -Change "Add" -Config $Config -Apply $true
            $r.Message | Should -Match "already in"
            Should -Invoke Add-ADGroupMember -ModuleName Requests -Times 0 -Exactly
        }

        It "removes someone from an allowed group" {
            Mock Get-ADGroupMember { [pscustomobject]@{ SamAccountName = "jdoe" } } -ModuleName Requests
            $r = Invoke-GroupAccessRequest -SamAccountName "jdoe" -Group "GRP-VPN" -Change "Remove" -Config $Config -Apply $true
            $r.Message | Should -Match "Removed jdoe"
        }
    }

    Context "Form mapping" {

        It "maps a group access form" {
            $row = ConvertTo-RequestRow -Fields @{ RequestType = "Group access"; Username = "jdoe"; GroupName = "GRP-VPN"; GroupChange = "Add" }
            $row.Group  | Should -Be "GRP-VPN"
            $row.Change | Should -Be "Add"
        }
    }

    Context "Unknown request type" {

        It "says which type it doesn't handle instead of failing silently" {
            Mock ConvertTo-RequestRow { [pscustomobject]@{ SamAccountName = "jdoe" } } -ModuleName Requests

            $outcome = Invoke-Request -Fields @{ RequestType = "Office move" } -Configs @{ Requests = $Config } `
                                      -LogFile "TestDrive:\r.log" -Apply $false

            $outcome.Ok      | Should -BeFalse
            $outcome.Message | Should -Match "Office move"
        }
    }
}
