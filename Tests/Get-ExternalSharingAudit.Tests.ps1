Describe "Get-ExternalSharingAudit" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Audits -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Audits\Audits.psm1" -Force

        Mock Write-Log {} -ModuleName Audits
    }

    BeforeEach {
        Mock Get-PnPTenantSite {
            [pscustomobject]@{ Url = "https://c.sharepoint.com/sites/Open";    SharingCapability = "ExternalUserAndGuestSharing" }
            [pscustomobject]@{ Url = "https://c.sharepoint.com/sites/Guests";  SharingCapability = "ExternalUserSharing" }
            [pscustomobject]@{ Url = "https://c.sharepoint.com/sites/Closed";  SharingCapability = "Disabled" }
        } -ModuleName Audits

        Mock Get-PnPExternalUser {
            [pscustomobject]@{ AcceptedAs = "partner@vendor.com"; WhenCreated = (Get-Date).AddDays(-30) }
            [pscustomobject]@{ AcceptedAs = "old@vendor.com";     WhenCreated = (Get-Date).AddDays(-500) }
            [pscustomobject]@{ AcceptedAs = "stranger@other.com"; WhenCreated = (Get-Date).AddDays(-10) }
        } -ModuleName Audits
    }

    It "flags sites that allow anyone-with-the-link, ignores sites with sharing off" {
        $findings = @(Get-ExternalSharingAudit -Config ([pscustomobject]@{}))
        $sites = @($findings | Where-Object Name -like "https://*")

        $sites.Count | Should -Be 2
        ($sites | Where-Object Name -like "*Open").Flagged   | Should -BeTrue
        ($sites | Where-Object Name -like "*Guests").Flagged | Should -BeFalse
    }

    It "flags guests from domains that aren't approved" {
        $findings = @(Get-ExternalSharingAudit -Config ([pscustomobject]@{ AllowedSharingDomains = @("vendor.com") }))

        ($findings | Where-Object Name -eq "stranger@other.com").Reason  | Should -Match "approved sharing list"
        ($findings | Where-Object Name -eq "partner@vendor.com").Flagged | Should -BeFalse
    }

    It "flags guests invited longer ago than the review age" {
        $findings = @(Get-ExternalSharingAudit -Config ([pscustomobject]@{ ExternalUserMaxAgeDays = 365 }))

        ($findings | Where-Object Name -eq "old@vendor.com").Reason      | Should -Match "never reviewed"
        ($findings | Where-Object Name -eq "partner@vendor.com").Flagged | Should -BeFalse
    }

    It "keeps asking for guests until a short page comes back" {
        Mock Get-PnPExternalUser {
            if ($Position -eq 0) { 1..50 | ForEach-Object { [pscustomobject]@{ AcceptedAs = "g$_@vendor.com"; WhenCreated = (Get-Date) } } }
            else                 { [pscustomobject]@{ AcceptedAs = "last@vendor.com"; WhenCreated = (Get-Date) } }
        } -ModuleName Audits

        $findings = @(Get-ExternalSharingAudit -Config ([pscustomobject]@{}))

        ($findings | Where-Object Name -eq "last@vendor.com") | Should -Not -BeNullOrEmpty
        Should -Invoke Get-PnPExternalUser -ModuleName Audits -Times 2 -Exactly
    }
}
