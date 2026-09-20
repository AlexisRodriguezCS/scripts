Describe "New-OnboardingIdentity" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"

        function New-TestObject {
            param(
                [string]$Status = "Valid"
            )

            [pscustomobject]@{
                CorrelationId   = [guid]::NewGuid().ToString()
                Raw = [pscustomobject]@{
                    FirstName  = "John"
                    LastName   = "Doe"
                    Department = "IT"
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = $null
                Status         = $Status
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        $Config = [pscustomobject]@{
            UsernameFormat = "FirstLast"
            DefaultOU      = "DC=corp,DC=local"
            UPNSuffix      = "@corp.local"
            TenantDomain   = "tenant.onmicrosoft.com"
        }

        Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force

        $logFile = "$PSScriptRoot\..\Onboarding\Logs\Testing\New-OnboardingIdentity_test.txt"

        Mock Write-Log {}
    }

    It "skips identity creation if status is not Valid" {
        $obj = New-TestObject -Status "Invalid"

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity | Should -Be $null
    }

    It "creates identity with FirstLast username format" {
        $obj = New-TestObject

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity.SamAccountName | Should -Be "johndoe"
    }

    It "creates identity with FirstDotLast username format" {
        $obj = New-TestObject
        $Config.UsernameFormat = "FirstDotLast"

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity.SamAccountName | Should -Be "john.doe"
    }

    It "falls back to default username format when unknown format is used" {
        $obj = New-TestObject
        $Config.UsernameFormat = "SomethingElse"

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity.SamAccountName | Should -Be "johndoe"
    }

    It "strips characters AD rejects and caps username at 20 chars" {
        $obj = New-TestObject
        $obj.Raw.FirstName = "Mary Ann"
        $obj.Raw.LastName  = "O'Brien-Castellanos"
        $Config.UsernameFormat = "FirstLast"

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity.SamAccountName | Should -Be "maryannobriencastell"
    }

    It "sets correct display name" {
        $obj = New-TestObject

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity.DisplayName | Should -Be "John Doe"
    }

    It "builds correct UPN and Entra UPN" {
        $obj = New-TestObject

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity.UserPrincipalName | Should -Be "johndoe@corp.local"
        $obj.Identity.EntraUPN          | Should -Be "johndoe@tenant.onmicrosoft.com"
    }

    It "builds correct OU path based on department" {
        $obj = New-TestObject

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity.OU | Should -Be "OU=IT,DC=corp,DC=local"
    }

    It "marks step as completed" {
        $obj = New-TestObject

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.StepsCompleted | Should -Contain "New-OnboardingIdentity"
    }

    It "does not run step twice if already completed" {
        $obj = New-TestObject
        $obj.StepsCompleted.Add("New-OnboardingIdentity") | Out-Null

        $before = $obj.Identity

        New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Identity | Should -Be $before
    }

    Context "Details HR filled in" {

        It "carries title, department and office into the identity" {
            $obj = New-TestObject
            $obj.Raw | Add-Member Title "Accountant" -Force
            $obj.Raw | Add-Member Location "Chicago" -Force

            New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config ([pscustomobject]@{
                UsernameFormat = "FirstLast"; DefaultOU = "DC=corp,DC=local"; UPNSuffix = "@corp.local"
                TenantDomain = "tenant.onmicrosoft.com"; Company = "Contoso"
            })

            $obj.Identity.Title      | Should -Be "Accountant"
            $obj.Identity.Department | Should -Be "IT"
            $obj.Identity.Office     | Should -Be "Chicago"
            $obj.Identity.Company    | Should -Be "Contoso"
        }

        It "finds the manager by the full name HR typed" {
            Mock Get-ADUser { [pscustomobject]@{ DistinguishedName = "CN=Boss,OU=IT,DC=corp,DC=local" } } -ModuleName Onboarding

            $obj = New-TestObject
            $obj.Raw | Add-Member Manager "Mary Johnson" -Force

            New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

            $obj.Identity.ManagerDN | Should -Be "CN=Boss,OU=IT,DC=corp,DC=local"
            Should -Invoke Get-ADUser -ModuleName Onboarding -Times 1 -Exactly -ParameterFilter {
                $Filter -like "*DisplayName -eq 'Mary Johnson'*"
            }
        }

        It "still creates the account when the manager can't be found" {
            Mock Get-ADUser { } -ModuleName Onboarding

            $obj = New-TestObject
            $obj.Raw | Add-Member Manager "Ghost Person" -Force

            New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

            $obj.Identity.ManagerDN | Should -BeNullOrEmpty
            $obj.Status             | Should -Be "Valid"
        }

        It "won't guess when two people share the manager's name" {
            Mock Get-ADUser {
                [pscustomobject]@{ DistinguishedName = "CN=Mary Johnson,OU=IT,DC=corp,DC=local" }
                [pscustomobject]@{ DistinguishedName = "CN=Mary Johnson,OU=HR,DC=corp,DC=local" }
            } -ModuleName Onboarding

            $obj = New-TestObject
            $obj.Raw | Add-Member Manager "Mary Johnson" -Force

            New-OnboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

            $obj.Identity.ManagerDN | Should -BeNullOrEmpty
        }
    }
}