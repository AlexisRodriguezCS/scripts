Describe "Hide-OffboardingFromAddressBook" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        $identity = [pscustomobject]@{ SamAccountName = "jdoe"; DistinguishedName = "CN=Jane Doe,OU=IT,DC=corp,DC=local" }
    }

    It "hides the user through the AD attribute (synced to Exchange Online)" {
        Mock Get-ADUser { [pscustomobject]@{ msExchHideFromAddressLists = $null } } -ModuleName Offboarding
        Mock Set-ADUser {} -ModuleName Offboarding

        Hide-OffboardingFromAddressBook -Identity $identity -LogFile "TestDrive:\x.log" | Should -Be "Hidden"
        Should -Invoke Set-ADUser -ModuleName Offboarding -Times 1 -Exactly -ParameterFilter { $Replace.msExchHideFromAddressLists -eq $true }
    }

    It "does nothing when already hidden" {
        Mock Get-ADUser { [pscustomobject]@{ msExchHideFromAddressLists = $true } } -ModuleName Offboarding
        Mock Set-ADUser {} -ModuleName Offboarding

        Hide-OffboardingFromAddressBook -Identity $identity -LogFile "TestDrive:\x.log" | Should -Be "AlreadyHidden"
        Should -Invoke Set-ADUser -ModuleName Offboarding -Times 0 -Exactly
    }

    It "explains clearly when AD doesn't have the Exchange attribute" {
        Mock Get-ADUser { [pscustomobject]@{} } -ModuleName Offboarding
        Mock Set-ADUser { throw "The specified directory service attribute or value does not exist" } -ModuleName Offboarding

        { Hide-OffboardingFromAddressBook -Identity $identity -LogFile "TestDrive:\x.log" } | Should -Throw "*Exchange schema not extended*"
    }
}
