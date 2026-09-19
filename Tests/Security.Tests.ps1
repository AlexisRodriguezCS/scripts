Describe "Security guard rails" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        . "$PSScriptRoot\..\Modules\Shared\Write-Log.ps1"
        . "$PSScriptRoot\..\Modules\Shared\Get-Config.ps1"
        . "$PSScriptRoot\..\Modules\Shared\Test-ProtectedAccount.ps1"
        . "$PSScriptRoot\..\Modules\Shared\Resolve-EntraUpn.ps1"
        . "$PSScriptRoot\..\Requests\Functions\Test-RequestApproval.ps1"
    }

    Context "Secrets in config" {

        BeforeAll {
            $null = New-Item -ItemType Directory -Path "TestDrive:\Config\Clients\Acme" -Force
            @{ TenantDomain = "acme.onmicrosoft.com"; AlertWebhookUrl = "secret:Acme-TeamsWebhook" } |
                ConvertTo-Json | Out-File "TestDrive:\Config\Clients\Acme\Audits.json"
        }

        It "replaces a secret reference with the value from the vault" {
            Mock Get-Secret { "https://hooks.example.com/abc123" } -ParameterFilter { $Name -eq "Acme-TeamsWebhook" -and $AsPlainText }

            $config = Get-Config -Script "Audits" -Client "Acme" -RootPath (Resolve-Path "TestDrive:\").Path

            $config.AlertWebhookUrl | Should -Be "https://hooks.example.com/abc123"
            $config.TenantDomain    | Should -Be "acme.onmicrosoft.com"
        }

        It "never writes a loaded secret to the log" {
            Mock Get-Secret { "https://hooks.example.com/abc123" }
            $null = Get-Config -Script "Audits" -Client "Acme" -RootPath (Resolve-Path "TestDrive:\").Path

            Write-Log -Message "Alert failed: 404 from https://hooks.example.com/abc123" -LogFile "TestDrive:\app.log" 6>$null

            $log = Get-Content "TestDrive:\app.log" -Raw
            $log | Should -Not -Match "abc123"
            $log | Should -Match "Alert failed: 404 from \*\*\*"
        }

        It "fails with the secret's name, not its value, when the vault can't be read" {
            Mock Get-Secret { throw "vault locked" }

            { Get-Config -Script "Audits" -Client "Acme" -RootPath (Resolve-Path "TestDrive:\").Path } |
                Should -Throw "*Acme-TeamsWebhook*"
        }
    }

    Context "Protected accounts" {

        It "protects AD admins" {
            Test-ProtectedAccount -AdUser ([pscustomobject]@{ SamAccountName = "admin"; adminCount = 1 }) -Config ([pscustomobject]@{}) |
                Should -Match "AD admin"
        }

        It "protects accounts on the list" {
            Test-ProtectedAccount -AdUser ([pscustomobject]@{ SamAccountName = "ceo"; adminCount = $null }) -Config ([pscustomobject]@{ ProtectedAccounts = @("ceo") }) |
                Should -Match "ProtectedAccounts"
        }

        It "lets IT override by hand" {
            Test-ProtectedAccount -AdUser ([pscustomobject]@{ SamAccountName = "admin"; adminCount = 1 }) -Config ([pscustomobject]@{ AllowProtected = $true }) |
                Should -BeNullOrEmpty
        }

        It "doesn't block normal users" {
            Test-ProtectedAccount -AdUser ([pscustomobject]@{ SamAccountName = "jdoe"; adminCount = $null }) -Config ([pscustomobject]@{ ProtectedAccounts = @("ceo") }) |
                Should -BeNullOrEmpty
        }
    }

    Context "Entra UPN" {

        It "uses the AD UPN when it's routable" {
            Resolve-EntraUpn -SamAccountName "jdoe" -AdUpn "jane.doe@contoso.com" -Config ([pscustomobject]@{ UseAdUpnForEntra = $true; TenantDomain = "contoso.onmicrosoft.com" }) |
                Should -Be "jane.doe@contoso.com"
        }

        It "falls back to the tenant domain in a .local lab" {
            Resolve-EntraUpn -SamAccountName "jdoe" -AdUpn "jdoe@contoso.local" -Config ([pscustomobject]@{ TenantDomain = "contoso.onmicrosoft.com" }) |
                Should -Be "jdoe@contoso.onmicrosoft.com"
        }
    }

    Context "Request approval" {

        BeforeAll {
            $Config = [pscustomobject]@{ Approvers = @("lead@corp.com") }

            function New-Version([string]$Status, [string]$By, [int]$Minute) {
                [pscustomobject]@{
                    LastModifiedDateTime = ([datetime]"2026-09-19T10:00:00").AddMinutes($Minute)
                    LastModifiedBy       = [pscustomobject]@{ User = [pscustomobject]@{ AdditionalProperties = @{ email = $By } } }
                    Fields               = [pscustomobject]@{ AdditionalProperties = @{ Status = $Status } }
                }
            }
        }

        It "accepts an approval by an approver" {
            $versions = @((New-Version "New" "hr@corp.com" 0), (New-Version "Approved" "lead@corp.com" 5))
            Test-RequestApproval -Versions $versions -SubmittedBy "hr@corp.com" -Config $Config | Should -BeNullOrEmpty
        }

        It "rejects someone who just typed Approved" {
            $versions = @((New-Version "New" "hr@corp.com" 0), (New-Version "Approved" "hr@corp.com" 5))
            Test-RequestApproval -Versions $versions -SubmittedBy "hr@corp.com" -Config $Config | Should -Match "isn't on the approvers list"
        }

        It "rejects approvers approving their own request" {
            $versions = @((New-Version "Approved" "lead@corp.com" 0))
            Test-RequestApproval -Versions $versions -SubmittedBy "lead@corp.com" -Config $Config | Should -Match "same person"
        }

        It "uses the latest approval, not an old one" {
            $versions = @(
                (New-Version "Approved" "lead@corp.com" 0),
                (New-Version "Needs attention" "app@corp.com" 5),
                (New-Version "Approved" "hr@corp.com" 10)
            )
            Test-RequestApproval -Versions $versions -SubmittedBy "hr@corp.com" -Config $Config | Should -Not -BeNullOrEmpty
        }

        It "rejects a request with no approval at all" {
            Test-RequestApproval -Versions @((New-Version "New" "hr@corp.com" 0)) -SubmittedBy "hr@corp.com" -Config $Config | Should -Match "No approval"
        }
    }
}
