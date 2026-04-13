Describe "Import-OnboardingCsv" {

    BeforeAll {
        Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force
        Mock Write-Log {}

        $validCsv = "$PSScriptRoot\..\Onboarding\Data\test.csv"
        $invalidCsv = "$PSScriptRoot\..\Onboarding\Data\nonexistent.csv"
        $logFile = "$PSScriptRoot\..\Onboarding\Logs\ImportCsv_test.txt"

        $result = Import-OnboardingCsv -Path $validCsv -LogFile $logFile
    }

    It "returns users" {
        $result.Count | Should -Be 2
    }

    It "maps names correctly" {
        $result[0].Raw.FirstName | Should -Be "John"
        $result[1].Raw.FirstName | Should -Be "Lisa"
    }

    It "initializes status" {
        $result.Status | Should -Contain "Pending"
    }

    It "has required properties" {
        $result[0].CorrelationId | Should -Not -BeNullOrEmpty
        $result[0].Raw | Should -Not -BeNullOrEmpty
        $result[0].Plan.Count | Should -Be 0
    }

    It "throws on missing file" {
        { Import-OnboardingCsv -Path "missing.csv" -LogFile $logFile} | Should -Throw
    }
}