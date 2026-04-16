Describe "New-OnboardingIdentity" {

    BeforeAll {

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
}