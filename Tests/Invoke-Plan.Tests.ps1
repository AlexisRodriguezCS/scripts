Describe "Invoke-Plan" {

    BeforeAll {
        . "$PSScriptRoot\..\Modules\Shared\Write-Log.ps1"
        . "$PSScriptRoot\..\Modules\Shared\Add-PipelineError.ps1"
        . "$PSScriptRoot\..\Modules\Shared\Invoke-Plan.ps1"

        function New-TestObject([array]$Plan) {
            [pscustomobject]@{
                CorrelationId = [guid]::NewGuid().ToString()
                Plan          = $Plan
                Errors        = [System.Collections.Generic.List[object]]::new()
                Status        = "Valid"
            }
        }

        $logFile = "TestDrive:\plan.log"
        Mock Write-Log {}
        Mock Start-Sleep {}
        Mock Get-Random { 1 }
    }

    It "runs each action and records the result text" {
        $obj = New-TestObject @(@{ Action = "A"; Target = "G1"; Result = $null })
        $actions = @{ A = @{ MaxRetries = 1; DelaySeconds = 0; Run = { param($p, $t) "Removed" } } }

        Invoke-Plan -PipelineObject $obj -Actions $actions -ResultText @{ Removed = "Removed from {0}" } -LogFile $logFile | Should -BeTrue
        $obj.Plan[0].Result | Should -Be "Removed from G1"
    }

    It "passes the plan item so actions can read extra values" {
        $obj = New-TestObject @(@{ Action = "A"; Target = "Title"; Value = "Manager"; Result = $null })
        $actions = @{ A = @{ MaxRetries = 1; DelaySeconds = 0; Run = { param($p, $t, $item) "set $t to $($item.Value)" } } }

        $null = Invoke-Plan -PipelineObject $obj -Actions $actions -LogFile $logFile
        $obj.Plan[0].Result | Should -Be "set Title to Manager"
    }

    It "retries with backoff and succeeds" {
        $script:calls = 0
        $obj = New-TestObject @(@{ Action = "A"; Target = "x"; Result = $null })
        $actions = @{ A = @{ MaxRetries = 3; DelaySeconds = 5; Run = { param($p, $t) $script:calls++; if ($script:calls -lt 3) { throw "timeout" }; "ok" } } }

        Invoke-Plan -PipelineObject $obj -Actions $actions -LogFile $logFile | Should -BeTrue
        Should -Invoke Start-Sleep -Times 2 -Exactly
    }

    It "records an error and keeps going when an action keeps failing" {
        $obj = New-TestObject @(
            @{ Action = "Bad";  Target = "x"; Result = $null },
            @{ Action = "Good"; Target = "y"; Result = $null }
        )
        $actions = @{
            Bad  = @{ MaxRetries = 2; DelaySeconds = 0; Run = { throw "nope" } }
            Good = @{ MaxRetries = 1; DelaySeconds = 0; Run = { "ok" } }
        }

        Invoke-Plan -PipelineObject $obj -Actions $actions -LogFile $logFile | Should -BeFalse
        $obj.Plan[0].Result | Should -Be "Failed"
        $obj.Plan[1].Result | Should -Be "ok"
        $obj.Errors.Count   | Should -Be 1
    }

    It "stops the whole plan when a StopOnFailure action fails" {
        $obj = New-TestObject @(
            @{ Action = "Disable"; Target = "x"; Result = $null },
            @{ Action = "Other";   Target = "y"; Result = $null }
        )
        $actions = @{
            Disable = @{ MaxRetries = 1; DelaySeconds = 0; Run = { throw "access denied" } }
            Other   = @{ MaxRetries = 1; DelaySeconds = 0; Run = { "ran" } }
        }

        Invoke-Plan -PipelineObject $obj -Actions $actions -StopOnFailure "Disable" -LogFile $logFile | Should -BeFalse
        $obj.Plan[1].Result | Should -BeNullOrEmpty
    }

    It "fails on an unknown action" {
        $obj = New-TestObject @(@{ Action = "Mystery"; Target = "x"; Result = $null })

        Invoke-Plan -PipelineObject $obj -Actions @{} -LogFile $logFile | Should -BeFalse
        $obj.Errors.Count | Should -Be 1
    }
}
