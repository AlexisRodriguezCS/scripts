Describe "ConvertTo-OnboardingStandard" {

    BeforeAll {
        function New-TestObject {
            [pscustomobject]@{
                CorrelationId   = [guid]::NewGuid().ToString()
                Raw = [pscustomobject]@{
                    FirstName  = "  john  "
                    LastName   = "  doe  "
                    Title      = "  software engineer  "
                    Manager    = "  jane smith  "
                    Location   = "  chicago  "
                    Department = "  it  "
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
        $logFile = "$PSScriptRoot\..\Onboarding\Logs\ConvertTo-OnboardingStandard_test.txt"
        Mock Write-Log {}
    }

    

    It "converts names correctly" {
        $obj = New-TestObject
        ConvertTo-OnboardingStandard -PipelineObject $obj -LogFile $logFile

        $obj.Raw.FirstName | Should -Be "John"
        $obj.Raw.LastName  | Should -Be "Doe"
        $obj.Raw.Title     | Should -Be "Software Engineer"
    }

    It "normalizes department with exceptions" {
        $obj = New-TestObject
        ConvertTo-OnboardingStandard -PipelineObject $obj -LogFile $logFile

        $obj.Raw.Department | Should -Be "IT"
    }

    It "marks step as completed" {
        $obj = New-TestObject
        ConvertTo-OnboardingStandard -PipelineObject $obj -LogFile $logFile

        $obj.StepsCompleted | Should -Contain "ConvertTo-OnboardingStandard"
    }

    It "handles null values without throwing" {
        $obj = New-TestObject
        $obj.Raw.FirstName = $null

        { ConvertTo-OnboardingStandard -PipelineObject $obj -LogFile $logFile } | Should -Not -Throw
    }

    It "does not alter already formatted values incorrectly" {
        $obj = New-TestObject
        $obj.Raw.FirstName = "John"
        $obj.Raw.LastName  = "Doe"
        $obj.Raw.Title     = "Software Engineer"

        ConvertTo-OnboardingStandard -PipelineObject $obj -LogFile $logFile

        $obj.Raw.FirstName | Should -Be "John"
        $obj.Raw.LastName  | Should -Be "Doe"
        $obj.Raw.Title     | Should -Be "Software Engineer"
    }

    It "normalizes non-exception department correctly" {
        $obj = New-TestObject
        $obj.Raw.Department = "finance"

        ConvertTo-OnboardingStandard -PipelineObject $obj -LogFile $logFile

        $obj.Raw.Department | Should -Be "Finance"
    }
}