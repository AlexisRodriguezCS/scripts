Describe "Start-Onboarding" {

    BeforeAll {
        Remove-Module Onboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force

        function New-TestObject {
            param(
                [string]$Status = "Valid",
                [array]$Plan = @()
            )
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
                Plan           = $Plan
                Status         = $Status
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        function New-PlanItem {
            param([string]$Action, [string]$Target = "")
            [pscustomobject]@{ Action = $Action; Target = $Target; Result = $null }
        }

        $script:logFile = "$PSScriptRoot\..\Onboarding\Logs\Testing\Start-Onboarding_test.txt"

        $script:config = [pscustomobject]@{ License = "ENTERPRISEPACK" }

        Mock Write-Log        {} -ModuleName Onboarding
        Mock Add-PipelineError {} -ModuleName Onboarding
        Mock Start-Sleep      {} -ModuleName Onboarding
        Mock Get-Random       { return 1 } -ModuleName Onboarding
    }

    # ---------------------------------------------------------------
    # Guard clauses
    # ---------------------------------------------------------------

    It "skips processing and returns early when status is Invalid" {
        $obj = New-TestObject -Status "Invalid"

        $result = Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $result.Status | Should -Be "Invalid"
        Assert-MockCalled Write-Log -Times 1 -ModuleName Onboarding
    }

    It "skips processing and returns early when status is Failed" {
        $obj = New-TestObject -Status "Failed"

        $result = Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $result.Status | Should -Be "Failed"
        Assert-MockCalled Write-Log -Times 1 -ModuleName Onboarding
    }

    # ---------------------------------------------------------------
    # Unknown action
    # ---------------------------------------------------------------

    It "calls Add-PipelineError and returns early for unknown action" {
        $obj = New-TestObject -Plan @(New-PlanItem -Action "DoSomethingFake" -Target "target")

        $result = Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        Assert-MockCalled Add-PipelineError -Times 1 -ModuleName Onboarding
        $obj.Plan[0].Result | Should -BeNullOrEmpty
    }

    # ---------------------------------------------------------------
    # Happy path — each action type
    # ---------------------------------------------------------------

    It "executes WaitForEntra and records result" {
        Mock Wait-ForEntraUser { return "Found" } -ModuleName Onboarding

        $obj = New-TestObject -Plan @(New-PlanItem -Action "WaitForEntra")

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Plan[0].Result | Should -Be "User found"
        Assert-MockCalled Wait-ForEntraUser -Times 1 -ModuleName Onboarding
    }

    It "executes AddToGroup and records result" {
        Mock Add-OnboardingGroupMember { return "Added" } -ModuleName Onboarding

        $obj = New-TestObject -Plan @(New-PlanItem -Action "AddToGroup" -Target "IT-Staff")

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Plan[0].Result | Should -Be "Added to IT-Staff"
        Assert-MockCalled Add-OnboardingGroupMember -Times 1 -ModuleName Onboarding
    }

    It "executes AddToDistributionList and records result" {
        Mock Add-OnboardingDLMember { return "Added" } -ModuleName Onboarding

        $obj = New-TestObject -Plan @(New-PlanItem -Action "AddToDistributionList" -Target "IT-DL")

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Plan[0].Result | Should -Be "Added to IT-DL"
        Assert-MockCalled Add-OnboardingDLMember -Times 1 -ModuleName Onboarding
    }

    It "executes AssignLicense and records result" {
        Mock Set-OnboardingLicense { return "AlreadyAssigned" } -ModuleName Onboarding

        $obj = New-TestObject -Plan @(New-PlanItem -Action "AssignLicense" -Target "ENTERPRISEPACK")

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Plan[0].Result | Should -Be "Already assigned ENTERPRISEPACK"
        Assert-MockCalled Set-OnboardingLicense -Times 1 -ModuleName Onboarding
    }

    It "records AlreadyExists result when group member already present" {
        Mock Add-OnboardingGroupMember { return "AlreadyExists" } -ModuleName Onboarding

        $obj = New-TestObject -Plan @(New-PlanItem -Action "AddToGroup" -Target "IT-Staff")

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Plan[0].Result | Should -Be "Already in IT-Staff"
    }

    # ---------------------------------------------------------------
    # Retry logic
    # ---------------------------------------------------------------

    It "retries AddToGroup on failure and succeeds within max retries" {
        $script:callCount = 0
        Mock Add-OnboardingGroupMember {
            $script:callCount++
            if ($script:callCount -lt 3) { throw "Transient error" }
            return "Added"
        } -ModuleName Onboarding

        $obj = New-TestObject -Plan @(New-PlanItem -Action "AddToGroup" -Target "IT-Staff")

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Plan[0].Result              | Should -Be "Added to IT-Staff"
        Assert-MockCalled Add-OnboardingGroupMember -Times 3 -ModuleName Onboarding
        Assert-MockCalled Start-Sleep -Times 2 -ModuleName Onboarding
    }

    It "marks result as Failed and calls Add-PipelineError when all retries exhausted" {
        Mock Add-OnboardingGroupMember { throw "Persistent error" } -ModuleName Onboarding

        $obj = New-TestObject -Plan @(New-PlanItem -Action "AddToGroup" -Target "IT-Staff")

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Plan[0].Result | Should -Be "Failed"
        Assert-MockCalled Add-OnboardingGroupMember -Times 3 -ModuleName Onboarding  # MaxRetries for AddToGroup
        Assert-MockCalled Add-PipelineError -Times 1 -ModuleName Onboarding
    }

    # ---------------------------------------------------------------
    # WaitForEntra abort
    # ---------------------------------------------------------------

    It "aborts pipeline early when WaitForEntra exhausts all retries" {
        Mock Wait-ForEntraUser    { throw "Not found" } -ModuleName Onboarding
        Mock Add-OnboardingGroupMember {} -ModuleName Onboarding

        $plan = @(
            New-PlanItem -Action "WaitForEntra"
            New-PlanItem -Action "AddToGroup" -Target "IT-Staff"
        )
        $obj = New-TestObject -Plan $plan

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        # Second action should never have run
        $obj.Plan[1].Result | Should -BeNullOrEmpty
        Assert-MockCalled Add-OnboardingGroupMember -Times 0 -ModuleName Onboarding
        Assert-MockCalled Wait-ForEntraUser -Times 10 -ModuleName Onboarding  # MaxRetries for WaitForEntra
    }

    # ---------------------------------------------------------------
    # Final status rollup
    # ---------------------------------------------------------------

    It "sets status to Failed at end if pipeline has errors" {
        Mock Add-OnboardingGroupMember { throw "Persistent error" } -ModuleName Onboarding

        # Give the object a pre-populated error to simulate accumulated failures
        $obj = New-TestObject -Plan @(New-PlanItem -Action "AddToGroup" -Target "IT-Staff")
        Mock Add-PipelineError {
            $PipelineObject.Errors.Add([pscustomobject]@{ Step = $Step; Message = $Message })
        } -ModuleName Onboarding

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Status | Should -Be "Failed"
    }

    It "does not change status when plan completes with no errors" {
        Mock Add-OnboardingGroupMember { return "Added" } -ModuleName Onboarding

        $obj = New-TestObject -Plan @(New-PlanItem -Action "AddToGroup" -Target "IT-Staff")

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Status | Should -Be "Valid"
    }

    # ---------------------------------------------------------------
    # Multi-step plan
    # ---------------------------------------------------------------

    It "executes all steps in order when plan has multiple actions" {
        Mock Wait-ForEntraUser         { return "Found" }  -ModuleName Onboarding
        Mock Add-OnboardingGroupMember { return "Added" }  -ModuleName Onboarding
        Mock Set-OnboardingLicense     { return "AlreadyAssigned" } -ModuleName Onboarding

        $plan = @(
            New-PlanItem -Action "WaitForEntra"
            New-PlanItem -Action "AddToGroup"   -Target "IT-Staff"
            New-PlanItem -Action "AssignLicense" -Target "ENTERPRISEPACK"
        )
        $obj = New-TestObject -Plan $plan

        Start-Onboarding -PipelineObject $obj -LogFile $script:logFile -Config $script:config

        $obj.Plan[0].Result | Should -Be "User found"
        $obj.Plan[1].Result | Should -Be "Added to IT-Staff"
        $obj.Plan[2].Result | Should -Be "Already assigned ENTERPRISEPACK"
    }
}