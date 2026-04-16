Describe "Set-OnboardingPolicy" {

    BeforeAll {

        function New-TestObject {
            param(
                [string]$Role = "Admin",
                [string]$Title = "Manager",
                [string]$Department = "IT",
                [string]$EmploymentType = "Regular Full-Time"
            )

            [pscustomobject]@{
                CorrelationId   = [guid]::NewGuid().ToString()
                Raw = [pscustomobject]@{
                    FirstName      = "John"
                    LastName       = "Doe"
                    Title          = $Title
                    Department     = $Department
                    EmploymentType = $EmploymentType
                    Role           = $Role
                    DistributionList = $null
                    ADGroups         = $null
                    License          = $null
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = $null
                Status         = "Pending"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        $Config = [pscustomobject]@{
            DefaultDistributionList = "AllStaff"
            DefaultGroups           = @("GRP_BASE_Users")
            DefaultLicense          = "Microsoft365BusinessBasic"
        }

        Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force

        $logFile = "$PSScriptRoot\..\Onboarding\Logs\Testing\Set-OnboardingPolicy_test.txt"

        Mock Write-Log {}
    }

    It "assigns department, managers, and default DL correctly" {
        $obj = New-TestObject

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.DistributionList | Should -Be "IT;Managers;AllStaff"
    }

    It "adds Managers DL when title contains keyword (case-insensitive)" {
        $obj = New-TestObject -Title "senior director"

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.DistributionList | Should -Match "Managers"
    }

    It "does not include department if missing" {
        $obj = New-TestObject -Department $null

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.DistributionList | Should -Not -Match "^IT"
    }

    It "does not add default DL for non full-time employees" {
        $obj = New-TestObject -EmploymentType "Contractor"

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.DistributionList | Should -Not -Match "AllStaff"
    }

    It "assigns correct AD group for Admin role" {
        $obj = New-TestObject -Role "Admin"

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.ADGroups | Should -Match "GRP_ROLE_IT_Admin"
    }

    It "assigns correct AD group for Developer role" {
        $obj = New-TestObject -Role "Developer"

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.ADGroups | Should -Match "GRP_ROLE_IT_User"
    }

    It "falls back to default group for unknown role" {
        $obj = New-TestObject -Role "UnknownRole"

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.ADGroups | Should -Match "GRP_ROLE_User"
    }

    It "appends default groups from config" {
        $obj = New-TestObject

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.ADGroups | Should -Match "GRP_BASE_Users"
    }

    It "assigns license from config" {
        $obj = New-TestObject

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Raw.License | Should -Be "Microsoft365BusinessBasic"
    }

    It "does not run step twice if already completed" {
        $obj = New-TestObject
        $obj.StepsCompleted.Add("Set-OnboardingPolicy") | Out-Null

        Set-OnboardingPolicy -PipelineObject $obj -LogFile $logFile -Config $Config

        # Values should remain unchanged
        $obj.Raw.DistributionList | Should -Be $null
        $obj.Raw.ADGroups         | Should -Be $null
        $obj.Raw.License          | Should -Be $null
    }
}