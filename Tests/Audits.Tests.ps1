Describe "Audits" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Audits -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Audits\Audits.psm1" -Force

        $now = [datetime]"2026-09-19"
        Mock Write-Log {} -ModuleName Audits
    }

    Context "Mfa" {

        It "flags users with no MFA and admins on SMS only" {
            Mock Get-MgReportAuthenticationMethodUserRegistrationDetail {
                [pscustomobject]@{ UserPrincipalName = "none@corp.com";  UserType = "member"; IsMfaRegistered = $false; IsAdmin = $false; MethodsRegistered = @() }
                [pscustomobject]@{ UserPrincipalName = "admin@corp.com"; UserType = "member"; IsMfaRegistered = $true;  IsAdmin = $true;  MethodsRegistered = @("mobilePhone") }
                [pscustomobject]@{ UserPrincipalName = "good@corp.com";  UserType = "member"; IsMfaRegistered = $true;  IsAdmin = $true;  MethodsRegistered = @("microsoftAuthenticatorPush") }
                [pscustomobject]@{ UserPrincipalName = "guest@x.com";    UserType = "guest";  IsMfaRegistered = $false; IsAdmin = $false; MethodsRegistered = @() }
            } -ModuleName Audits

            $findings = @(Get-MfaAudit)

            $findings.Count | Should -Be 3
            ($findings | Where-Object Name -eq "none@corp.com").Reason  | Should -Be "No MFA method registered"
            ($findings | Where-Object Name -eq "admin@corp.com").Reason | Should -Match "SMS"
            ($findings | Where-Object Name -eq "good@corp.com").Flagged | Should -BeFalse
        }
    }

    Context "AdminRoles" {

        It "flags too many Global Admins and guests with roles" {
            Mock Get-MgDirectoryRole { [pscustomobject]@{ Id = "1"; DisplayName = "Global Administrator" } } -ModuleName Audits
            Mock Get-MgDirectoryRoleMember {
                1..5 | ForEach-Object { [pscustomobject]@{ AdditionalProperties = @{ userPrincipalName = "admin$_@corp.com" } } }
                [pscustomobject]@{ AdditionalProperties = @{ userPrincipalName = "vendor_x.com#EXT#@corp.onmicrosoft.com" } }
            } -ModuleName Audits

            $findings = @(Get-AdminRoleAudit -Config ([pscustomobject]@{ MaxGlobalAdmins = 4 }))

            ($findings | Where-Object { $_.Reason -like "More than 4*" }).Count        | Should -Be 1
            ($findings | Where-Object { $_.Reason -like "Guest account*" }).Count      | Should -Be 1
        }
    }

    Context "AppCredentials" {

        It "flags expired and soon-to-expire secrets only" {
            Mock Get-MgApplication {
                [pscustomobject]@{
                    DisplayName = "Payroll Sync"
                    PasswordCredentials = @(
                        [pscustomobject]@{ DisplayName = "old";  EndDateTime = $now.AddDays(-2) },
                        [pscustomobject]@{ DisplayName = "soon"; EndDateTime = $now.AddDays(10) },
                        [pscustomobject]@{ DisplayName = "fine"; EndDateTime = $now.AddDays(300) }
                    )
                    KeyCredentials = @()
                }
            } -ModuleName Audits

            $findings = @(Get-AppCredentialAudit -Config ([pscustomobject]@{ CredentialWarningDays = 30 }) -Now $now)

            @($findings | Where-Object Flagged).Count | Should -Be 2
            ($findings | Where-Object { $_.Detail -like "*'old'*" }).Reason  | Should -Match "Expired"
            ($findings | Where-Object { $_.Detail -like "*'soon'*" }).Reason | Should -Match "Expires in 10 days"
        }
    }

    Context "Licenses" {

        BeforeAll {
            Mock Get-MgSubscribedSku {
                [pscustomobject]@{ SkuId = "sku-e3"; SkuPartNumber = "SPE_E3"; ConsumedUnits = 8; PrepaidUnits = [pscustomobject]@{ Enabled = 10 } }
            } -ModuleName Audits
            Mock Get-MgUser {
                [pscustomobject]@{ UserPrincipalName = "active@corp.com";   Department = "IT";      AccountEnabled = $true;  AssignedLicenses = @([pscustomobject]@{ SkuId = "sku-e3" }); SignInActivity = [pscustomobject]@{ LastSuccessfulSignInDateTime = $now.AddDays(-1) } }
                [pscustomobject]@{ UserPrincipalName = "disabled@corp.com"; Department = "IT";      AccountEnabled = $false; AssignedLicenses = @([pscustomobject]@{ SkuId = "sku-e3" }); SignInActivity = $null }
                [pscustomobject]@{ UserPrincipalName = "idle@corp.com";     Department = "Finance"; AccountEnabled = $true;  AssignedLicenses = @([pscustomobject]@{ SkuId = "sku-e3" }); SignInActivity = [pscustomobject]@{ LastSuccessfulSignInDateTime = $now.AddDays(-200) } }
            } -ModuleName Audits

            $script:findings = @(Get-LicenseAudit -Config ([pscustomobject]@{ InactiveDays = 90; LicensePrices = [pscustomobject]@{ SPE_E3 = 36 } }) -Now $now)
        }

        It "flags unused licenses with the monthly waste" {
            ($findings | Where-Object Name -eq "SPE_E3").Reason | Should -Match "2 unused"
        }

        It "flags licenses on disabled and idle accounts" {
            ($findings | Where-Object Name -eq "disabled@corp.com").Reason | Should -Match "disabled"
            ($findings | Where-Object Name -eq "idle@corp.com").Reason     | Should -Match "unused for 90"
            $findings.Name | Should -Not -Contain "active@corp.com"
        }

        It "totals cost per department" {
            ($findings | Where-Object { $_.Check -eq "LicenseCostByDepartment" -and $_.Name -eq "IT" }).Detail | Should -Match "2 users"
        }
    }

    Context "MailForwarding" {

        It "flags forwarding to outside domains only" {
            Mock Get-AcceptedDomain { [pscustomobject]@{ DomainName = "corp.com" } } -ModuleName Audits
            Mock Get-Mailbox {
                [pscustomobject]@{ PrimarySmtpAddress = "leaky@corp.com"; ForwardingSmtpAddress = "smtp:me@gmail.com" }
                [pscustomobject]@{ PrimarySmtpAddress = "fine@corp.com";  ForwardingSmtpAddress = "smtp:boss@corp.com" }
            } -ModuleName Audits
            Mock Get-InboxRule {
                if ($Mailbox -eq "fine@corp.com") {
                    [pscustomobject]@{ Name = "fwd"; Enabled = $true; ForwardTo = @('"X" [SMTP:x@evil.com]'); RedirectTo = $null; ForwardAsAttachmentTo = $null }
                }
            } -ModuleName Audits

            $findings = @(Get-MailForwardingAudit)

            ($findings | Where-Object { $_.Name -eq "leaky@corp.com" }).Flagged                          | Should -BeTrue
            ($findings | Where-Object { $_.Detail -like "Mailbox forwards to boss*" }).Flagged           | Should -BeFalse
            ($findings | Where-Object { $_.Detail -like "Inbox rule*" }).Reason                          | Should -Match "outside"
        }
    }

    Context "Export-AuditReport" {

        It "puts flagged findings under NEEDS ATTENTION" {
            $findings = @(
                (New-AuditFinding -Check "Mfa" -Name "a@corp.com" -Flagged $true -Reason "No MFA method registered"),
                (New-AuditFinding -Check "Mfa" -Name "b@corp.com")
            )

            $summary = Export-AuditReport -Check "Mfa" -Findings $findings -ReportDir "TestDrive:\" -RunStamp "test"

            $summary.Flagged | Should -Be 1
            Get-Content $summary.ReportFile | Should -Contain "=== NEEDS ATTENTION (1) ==="
        }
    }
}
