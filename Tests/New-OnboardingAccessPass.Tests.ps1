Describe "Temporary Access Pass" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Onboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force

        function New-TestObject([string]$StartDate) {
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Raw            = [pscustomobject]@{ FirstName = "Alex"; LastName = "Johnson"; StartDate = $StartDate; ADGroups = $null; DistributionList = $null; License = $null }
                Identity       = [pscustomobject]@{ EntraUPN = "alexjohnson@tenant.onmicrosoft.com" }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Status         = "Created"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        Mock Write-Log {} -ModuleName Onboarding
    }

    Context "Plan" {

        It "adds the access pass only when the client turns it on" {
            $off = New-TestObject; $on = New-TestObject
            New-OnboardingPlan -PipelineObject $off -LogFile "TestDrive:\x.log"
            New-OnboardingPlan -PipelineObject $on  -LogFile "TestDrive:\x.log" -Config ([pscustomobject]@{ UseTemporaryAccessPass = $true })

            $off.Plan.Action | Should -Not -Contain "CreateAccessPass"
            $on.Plan[1].Action | Should -Be "CreateAccessPass"   # right after the user exists in Entra
        }
    }

    Context "New-OnboardingAccessPass" {

        It "creates a pass that starts on the morning of the start date" {
            Mock Get-MgUserAuthenticationTemporaryAccessPassMethod { $null } -ModuleName Onboarding
            Mock New-MgUserAuthenticationTemporaryAccessPassMethod { [pscustomobject]@{ TemporaryAccessPass = "Xy7#kP2q" } } -ModuleName Onboarding

            $start = (Get-Date).AddDays(7).ToString("yyyy-MM-dd")
            $obj = New-TestObject -StartDate $start

            $result = New-OnboardingAccessPass -PipelineObject $obj -Config ([pscustomobject]@{}) -LogFile "TestDrive:\x.log"

            $result                  | Should -Match "Created"
            $obj.TemporaryAccessPass | Should -Be "Xy7#kP2q"
            Should -Invoke New-MgUserAuthenticationTemporaryAccessPassMethod -ModuleName Onboarding -Times 1 -Exactly -ParameterFilter {
                $BodyParameter.lifetimeInMinutes -eq 480 -and ([datetime]$BodyParameter.startDateTime).ToLocalTime().Hour -eq 8
            }
        }

        It "doesn't try to create a second pass on a re-run" {
            Mock Get-MgUserAuthenticationTemporaryAccessPassMethod { [pscustomobject]@{ Id = "existing" } } -ModuleName Onboarding
            Mock New-MgUserAuthenticationTemporaryAccessPassMethod {} -ModuleName Onboarding

            $result = New-OnboardingAccessPass -PipelineObject (New-TestObject) -Config ([pscustomobject]@{}) -LogFile "TestDrive:\x.log"

            $result | Should -Match "Already has an access pass"
            Should -Invoke New-MgUserAuthenticationTemporaryAccessPassMethod -ModuleName Onboarding -Times 0 -Exactly
        }
    }
}
