Describe "UserActivity" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module UserActivity -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\UserActivity\UserActivity.psm1" -Force

        $t0 = (Get-Date).Date.AddDays(-2).AddHours(10)   # "two days ago, 10:00"

        function New-SignIn([datetime]$Time, [int]$Code, [string]$App = "Outlook", [string]$Os = "iOS", $CaPolicy) {
            [pscustomobject]@{
                CreatedDateTime = $Time; AppDisplayName = $App; ClientAppUsed = "Mobile Apps"; IPAddress = "10.0.0.1"
                Status = [pscustomobject]@{ ErrorCode = $Code }
                Location = [pscustomobject]@{ City = "Chicago"; CountryOrRegion = "US" }
                DeviceDetail = [pscustomobject]@{ OperatingSystem = $Os; Browser = $null }
                AppliedConditionalAccessPolicies = @(if ($CaPolicy) { [pscustomobject]@{ DisplayName = $CaPolicy; Result = "failure" } })
            }
        }
    }

    Context "Sign-in error codes" {

        It "translates common codes into plain words" {
            ConvertTo-FriendlySignInError -ErrorCode 50126 | Should -Be "Wrong password"
            ConvertTo-FriendlySignInError -ErrorCode 50053 | Should -Match "locked"
            ConvertTo-FriendlySignInError -ErrorCode 53003 | Should -Match "Conditional Access"
            ConvertTo-FriendlySignInError -ErrorCode 999999 | Should -Match "look up"
        }
    }

    Context "Summary" {

        It "spots the classic: SSPR reset, then an old password still saved on a phone" {
            $events = @(
                (New-ActivityEvent -Time $t0 -Source "Entra audit" -Event "Reset password (self-service)" -Detail "By: jdoe@corp.com")
                (New-ActivityEvent -Time $t0.AddMinutes(30) -Source "Sign-in" -Event "Sign-in failed: Wrong password" -Result Failure -ErrorCode 50126 -Detail "App: Outlook | Client: x | Device: iOS | IP: 1")
                (New-ActivityEvent -Time $t0.AddMinutes(45) -Source "Sign-in" -Event "Sign-in failed: Wrong password" -Result Failure -ErrorCode 50126 -Detail "App: Outlook | Client: x | Device: iOS | IP: 1")
                (New-ActivityEvent -Time $t0.AddMinutes(50) -Source "Sign-in" -Event "Signed in: Success" -Result Success -Detail "App: Teams | Client: x | Device: Windows | IP: 1")
            )

            $summary = @(Get-ActivitySummary -Events $events -State $null)

            $summary[0] | Should -Match "Password was changed .* \(Reset password \(self-service\)\)"
            $summary[0] | Should -Match "2 sign-in\(s\) failed with the old password"
            $summary[0] | Should -Match "Outlook on iOS \(2x\)"
            ($summary -join " ") | Should -Match "Last successful sign-in: .*Teams"
        }

        It "doesn't mistake a wrong password for a password change" {
            $events = @(
                (New-ActivityEvent -Time $t0 -Source "AD" -Event "Wrong password (AD)" -Result Failure)
                (New-ActivityEvent -Time $t0.AddMinutes(1) -Source "Sign-in" -Event "Sign-in failed: Wrong password" -Result Failure -ErrorCode 50126 -Detail "App: Outlook")
            )
            $summary = @(Get-ActivitySummary -Events $events -State $null)
            ($summary -join " ") | Should -Not -Match "Password was changed"
            ($summary -join " ") | Should -Match "1 wrong-password sign-in"
        }

        It "works without SSPR: an admin reset or AD 'password set' counts too" {
            $events = @(
                (New-ActivityEvent -Time $t0 -Source "AD" -Event "Password set (AD)")
                (New-ActivityEvent -Time $t0.AddMinutes(5) -Source "Sign-in" -Event "Sign-in failed: Wrong password" -Result Failure -ErrorCode 50126 -Detail "App: Outlook | Device: Android")
            )
            (Get-ActivitySummary -Events $events -State $null)[0] | Should -Match "Password set \(AD\).*1 sign-in\(s\) failed with the old password"
        }

        It "leads with account state: locked out, and by which device" {
            $state = [pscustomobject]@{ Enabled = $true; LockedOut = $true; LockoutTime = $t0; PasswordExpired = $false; LockoutSources = @("JDOE-LAPTOP") }

            $summary = @(Get-ActivitySummary -Events @() -State $state)

            $summary[0] | Should -Match "LOCKED OUT"
            $summary[0] | Should -Match "JDOE-LAPTOP"
        }

        It "names the Conditional Access policy that blocked them" {
            $events = @((New-ActivityEvent -Time $t0 -Source "Sign-in" -Event "Sign-in failed: Blocked by a Conditional Access policy (Block non-US)" -Result Failure -ErrorCode 53003 -Detail "App: Teams"))
            (Get-ActivitySummary -Events $events -State $null) -join " " | Should -Match "Blocked by Conditional Access 1 time\(s\): Block non-US"
        }

        It "says when there were no sign-ins at all" {
            (Get-ActivitySummary -Events @() -State $null) -join " " | Should -Match "No sign-in attempts at all"
        }
    }

    Context "Full report" {

        BeforeEach {
            Mock Get-MgUser { [pscustomobject]@{ Id = "id-1"; DisplayName = "Jane Doe"; UserPrincipalName = "jdoe@corp.com"; OnPremisesSyncEnabled = $true; OnPremisesSamAccountName = "jdoe" } } -ModuleName UserActivity
            Mock Get-MgAuditLogSignIn { (New-SignIn $t0.AddMinutes(30) 50126), (New-SignIn $t0.AddMinutes(60) 0 "Teams" "Windows") } -ModuleName UserActivity
            Mock Get-MgAuditLogDirectoryAudit {
                if ($Filter -like "*initiatedBy*") {
                    [pscustomobject]@{ Id = "a1"; ActivityDateTime = $t0; ActivityDisplayName = "Reset password (self-service)"; Result = "success"; LoggedByService = "Self-service Password Management"; Category = "UserManagement"
                                       InitiatedBy = [pscustomobject]@{ User = [pscustomobject]@{ UserPrincipalName = "jdoe@corp.com" } } }
                }
            } -ModuleName UserActivity
            Mock Get-ADUser {
                [pscustomobject]@{ Enabled = $true; LockedOut = $false; PasswordLastSet = $t0; PasswordExpired = $false; badPwdCount = 1; LastBadPasswordAttempt = $t0.AddMinutes(30) }
            } -ModuleName UserActivity
        }

        It "writes a timeline with the summary on top, newest first" {
            $result = Invoke-UserActivityReport -UserPrincipalName "jdoe@corp.com" -Days 7

            $lines = Get-Content $result.ReportFile
            $lines | Should -Contain "=== SUMMARY ==="
            ($lines -join "`n") | Should -Match "Reset password \(self-service\)"
            $result.Summary[0] | Should -Match "failed with the old password"
            (Import-Csv $result.CsvFile)[0].Event | Should -Match "Signed in"   # newest first
        }

        It "works for on-prem only clients from AD alone" {
            Mock Get-MgUser { throw "Graph should not be called" } -ModuleName UserActivity
            Mock Get-ADUser {
                [pscustomobject]@{ DisplayName = "Jane Doe"; Enabled = $true; LockedOut = $true; AccountLockoutTime = $t0; PasswordLastSet = $t0.AddDays(-1); PasswordExpired = $false }
            } -ModuleName UserActivity

            $result = Invoke-UserActivityReport -SamAccountName "jdoe" -OnPremOnly -Days 7

            $result.Summary[0] | Should -Match "LOCKED OUT"
            Should -Invoke Get-MgAuditLogSignIn -ModuleName UserActivity -Times 0 -Exactly
        }

        It "explains what's missing when a source isn't licensed" {
            Mock Get-MgAuditLogSignIn { throw "Tenant does not have a SKU required" } -ModuleName UserActivity

            $result = Invoke-UserActivityReport -UserPrincipalName "jdoe@corp.com" -Days 7

            (Get-Content $result.ReportFile -Raw) | Should -Match "sign-in logs need Entra ID P1"
        }

        It "keeps going when one source can't be read" {
            Mock Get-MgAuditLogDirectoryAudit { throw "Insufficient privileges" } -ModuleName UserActivity

            $result = Invoke-UserActivityReport -UserPrincipalName "jdoe@corp.com" -Days 7

            (Get-Content $result.ReportFile -Raw) | Should -Match "Couldn't read Entra audit"
            (Get-Content $result.ReportFile -Raw) | Should -Match "Sign-in failed: Wrong password"
        }
    }
}
