Describe "New-OnboardingUser" {

    BeforeAll {
        Remove-Module Onboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force

        function New-TestObject {
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Identity       = [pscustomobject]@{
                    FirstName         = "John"
                    LastName          = "Doe"
                    DisplayName       = "John Doe"
                    SamAccountName    = "jdoe"
                    UserPrincipalName = "jdoe@corp.local"
                    OU                = "OU=IT,DC=corp,DC=local"
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Status         = "Valid"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        $script:logFile = "$PSScriptRoot\..\Onboarding\Logs\Testing\New-OnboardingUser_test.txt"

        Mock Write-Log {}          -ModuleName Onboarding
        Mock Add-PipelineError {}  -ModuleName Onboarding
    }

    It "sets status to AlreadyExists when user already exists in AD" {
        Mock Get-ADUser { return @{ SamAccountName = "jdoe" } } -ModuleName Onboarding
        Mock New-ADUser {}                                       -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status              | Should -Be "AlreadyExists"
        $obj.StepsCompleted      | Should -Contain "New-OnboardingUser"
        Assert-MockCalled New-ADUser -Times 0 -ModuleName Onboarding
    }

    It "creates user and sets status to Created when user does not exist" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status              | Should -Be "Created"
        $obj.StepsCompleted      | Should -Contain "New-OnboardingUser"
        Assert-MockCalled New-ADUser -Times 1 -ModuleName Onboarding
    }

    It "does not run step twice if already completed" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        $obj.StepsCompleted.Add("New-OnboardingUser") | Out-Null

        $before = $obj.Status
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be $before
        Assert-MockCalled New-ADUser -Times 0 -ModuleName Onboarding
    }

    It "does not run step if pipeline status is already Failed" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        $obj.Status = "Failed"

        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Failed"
        Assert-MockCalled New-ADUser -Times 0 -ModuleName Onboarding
    }

    It "does not run step if pipeline status is already Invalid" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        $obj.Status = "Invalid"

        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Invalid"
        Assert-MockCalled New-ADUser -Times 0 -ModuleName Onboarding
    }

    It "sets status to Failed when AD lookup throws" {
        Mock Get-ADUser { throw "AD down" } -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Failed"
        Assert-MockCalled Add-PipelineError -Times 1 -ModuleName Onboarding
    }

    It "sets status to Failed when New-ADUser throws" {
        Mock Get-ADUser { return $null }           -ModuleName Onboarding
        Mock New-ADUser { throw "Creation failed" } -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Failed"
        Assert-MockCalled Add-PipelineError -Times 1 -ModuleName Onboarding
    }

}