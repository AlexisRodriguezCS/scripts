Describe "Test-OffboardingData" {

    BeforeAll {
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        function New-TestObject {
            param(
                [string]$SamAccountName = "johndoe",
                [string]$Manager = ""
            )
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Raw            = [pscustomobject]@{ SamAccountName = $SamAccountName; Manager = $Manager }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = $null
                Status         = "Pending"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        $logFile = "TestDrive:\offboarding.log"
        Mock Write-Log {} -ModuleName Offboarding
    }

    It "marks a valid row as Valid" {
        $obj = New-TestObject -Manager "manager@corp.com"
        Test-OffboardingData -PipelineObject $obj -LogFile $logFile

        $obj.Status       | Should -Be "Valid"
        $obj.Errors.Count | Should -Be 0
    }

    It "marks a missing SamAccountName as Invalid" {
        $obj = New-TestObject -SamAccountName ""
        Test-OffboardingData -PipelineObject $obj -LogFile $logFile

        $obj.Status | Should -Be "Invalid"
        $obj.Errors | Should -Contain "SamAccountName is missing"
    }

    It "rejects SamAccountNames AD would reject (and that would break the AD filter)" {
        $obj = New-TestObject -SamAccountName "o'brien"
        Test-OffboardingData -PipelineObject $obj -LogFile $logFile

        $obj.Status | Should -Be "Invalid"
        $obj.Errors | Should -Contain "SamAccountName is invalid"
    }

    It "rejects a Manager that is not a UPN" {
        $obj = New-TestObject -Manager "Mary Smith"
        Test-OffboardingData -PipelineObject $obj -LogFile $logFile

        $obj.Status | Should -Be "Invalid"
        $obj.Errors | Should -Contain "Manager is not a valid UPN"
    }
}
