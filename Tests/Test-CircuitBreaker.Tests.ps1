Describe "Test-CircuitBreaker" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        Mock Write-Log {} -ModuleName Offboarding

        function New-User([string]$Status) {
            [pscustomobject]@{
                CorrelationId = [guid]::NewGuid().ToString()
                Raw           = [pscustomobject]@{ SamAccountName = "u$(Get-Random)" }
                Errors        = @([pscustomobject]@{ Step = "DisableAccount"; Exception = "The server is not operational" })
                Status        = $Status
            }
        }
    }

    It "does nothing until enough users have run" {
        $processed = @(1..4 | ForEach-Object { New-User "Failed" })
        Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{ MaxConsecutiveFailures = 5 }) | Should -BeFalse
    }

    It "trips after the limit is reached" {
        $processed = @(1..5 | ForEach-Object { New-User "Failed" })
        Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{ MaxConsecutiveFailures = 5 }) | Should -BeTrue
    }

    It "only looks at the run of failures at the end" {
        # 4 failures, then a success, then 4 more: nothing failed 5 times in a row
        $processed = @(1..4 | ForEach-Object { New-User "Failed" }) + @(New-User "Offboarded") + @(1..4 | ForEach-Object { New-User "Failed" })
        Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{ MaxConsecutiveFailures = 5 }) | Should -BeFalse
    }

    It "ignores bad data and missing users: those aren't an outage" {
        $processed = @(1..5 | ForEach-Object { New-User "NotFound" })
        Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{ MaxConsecutiveFailures = 5 }) | Should -BeFalse

        $processed = @(1..5 | ForEach-Object { New-User "Invalid" })
        Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{ MaxConsecutiveFailures = 5 }) | Should -BeFalse
    }

    It "defaults to 5 when the config doesn't set it" {
        $processed = @(1..4 | ForEach-Object { New-User "Failed" })
        Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{}) | Should -BeFalse

        $processed += New-User "Failed"
        Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{}) | Should -BeTrue
    }

    It "is switched off with 0" {
        $processed = @(1..20 | ForEach-Object { New-User "Failed" })
        Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{ MaxConsecutiveFailures = 0 }) | Should -BeFalse
    }

    It "handles an empty list" {
        Test-CircuitBreaker -Processed @() -Config ([pscustomobject]@{}) | Should -BeFalse
    }

    It "logs why it stopped" {
        $processed = @(1..5 | ForEach-Object { New-User "Failed" })
        $null = Test-CircuitBreaker -Processed $processed -Config ([pscustomobject]@{ MaxConsecutiveFailures = 5 })

        Should -Invoke Write-Log -ModuleName Offboarding -Times 1 -Exactly -ParameterFilter {
            $Message -like "*CircuitBreaker*" -and $Message -like "*not operational*" -and $Level -eq "ERROR"
        }
    }
}

Describe "Invoke-UserOffboarding circuit breaker" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        Mock Write-Log {} -ModuleName Offboarding
        Mock New-Report {} -ModuleName Offboarding
        Mock New-Item {} -ModuleName Offboarding
    }

    It "stops the run and marks the rest Stopped when everything keeps failing" {
        Mock Test-OffboardingData {} -ModuleName Offboarding
        Mock Get-OffboardingIdentity {} -ModuleName Offboarding
        Mock New-OffboardingPlan {} -ModuleName Offboarding
        Mock Start-Offboarding { $PipelineObject.Status = "Failed"; $PipelineObject } -ModuleName Offboarding

        $rows = @(1..10 | ForEach-Object { [pscustomobject]@{ SamAccountName = "user$_"; Manager = "" } })
        $config = [pscustomobject]@{ MaxConsecutiveFailures = 3; DisabledOU = "OU=Disabled,DC=corp,DC=local" }

        $result = Invoke-UserOffboarding -Rows $rows -LogFile "TestDrive:\x.log" -Config $config -Apply $true

        # 3 tried and failed, the other 7 never touched
        Should -Invoke Start-Offboarding -ModuleName Offboarding -Times 3 -Exactly
        $result.Failed  | Should -Be 3
        $result.Stopped | Should -Be 7
    }

    It "runs everyone when failures aren't consecutive" {
        Mock Test-OffboardingData {} -ModuleName Offboarding
        Mock Get-OffboardingIdentity {} -ModuleName Offboarding
        Mock New-OffboardingPlan {} -ModuleName Offboarding
        Mock Start-Offboarding {
            $PipelineObject.Status = if ($PipelineObject.Raw.SamAccountName -eq "user5") { "Offboarded" } else { "Failed" }
            $PipelineObject
        } -ModuleName Offboarding

        $rows = @(1..10 | ForEach-Object { [pscustomobject]@{ SamAccountName = "user$_"; Manager = "" } })
        $config = [pscustomobject]@{ MaxConsecutiveFailures = 6; DisabledOU = "OU=Disabled,DC=corp,DC=local" }

        $result = Invoke-UserOffboarding -Rows $rows -LogFile "TestDrive:\x.log" -Config $config -Apply $true

        Should -Invoke Start-Offboarding -ModuleName Offboarding -Times 10 -Exactly
        $result.Stopped | Should -Be 0
    }
}
