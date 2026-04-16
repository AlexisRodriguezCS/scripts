Describe "New-OnboardingPlan" {

    BeforeAll {

        function New-TestObject {
            param(
                [string]$ADGroups = "Group1;Group2",
                [string]$DistributionList = "DL1;DL2",
                [string]$License = "E3"
            )

            [pscustomobject]@{
                CorrelationId   = [guid]::NewGuid().ToString()
                Raw = [pscustomobject]@{
                    FirstName        = "John"
                    LastName         = "Doe"
                    ADGroups         = $ADGroups
                    DistributionList = $DistributionList
                    License          = $License
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = $null
                Status         = "Pending"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force

        $logFile = "$PSScriptRoot\..\Onboarding\Logs\Testing\New-OnboardingPlan_test.txt"

        Mock Write-Log {}
    }

    It "always adds WaitForEntra action first" {
        $obj = New-TestObject

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        $obj.Plan[0].Action | Should -Be "WaitForEntra"
    }

    It "adds group actions for each AD group" {
        $obj = New-TestObject -ADGroups "GroupA;GroupB"

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        ($obj.Plan | Where-Object Action -eq "AddToGroup").Count | Should -Be 2
    }

    It "adds distribution list actions" {
        $obj = New-TestObject -DistributionList "DL1;DL2"

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        ($obj.Plan | Where-Object Action -eq "AddToDistributionList").Count | Should -Be 2
    }

    It "adds license assignment when license exists" {
        $obj = New-TestObject -License "E5"

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        ($obj.Plan | Where-Object Action -eq "AssignLicense").Target | Should -Be "E5"
    }

    It "does not add group actions if ADGroups is null" {
        $obj = New-TestObject -ADGroups $null

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        ($obj.Plan | Where-Object Action -eq "AddToGroup").Count | Should -Be 0
    }

    It "does not add distribution list actions if DistributionList is null" {
        $obj = New-TestObject -DistributionList $null

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        ($obj.Plan | Where-Object Action -eq "AddToDistributionList").Count | Should -Be 0
    }

    It "does not add license action if License is null" {
        $obj = New-TestObject -License $null

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        ($obj.Plan | Where-Object Action -eq "AssignLicense").Count | Should -Be 0
    }

    It "resets existing plan before building a new one" {
        $obj = New-TestObject
        $obj.Plan = @(@{ Action = "OldAction"; Target = "X"; Result = $null })

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        ($obj.Plan | Where-Object Action -eq "OldAction").Count | Should -Be 0
    }

    It "does not run step twice if already completed" {
        $obj = New-TestObject
        $obj.StepsCompleted.Add("New-OnboardingPlan") | Out-Null

        $before = $obj.Plan.Clone()

        New-OnboardingPlan -PipelineObject $obj -LogFile $logFile

        $obj.Plan.Count | Should -Be $before.Count
    }
}