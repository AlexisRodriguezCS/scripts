Describe "PasswordExpiry" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module PasswordExpiry -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\PasswordExpiry\PasswordExpiry.psm1" -Force

        $logFile = "TestDrive:\expiry.log"
        $today   = [datetime]"2026-09-19"
        $Config  = [pscustomobject]@{ NotifyDays = @(14, 7, 1) }

        function New-TestUser {
            param([int]$DaysLeft, [string]$Mail = "user@corp.com")
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Raw            = [pscustomobject]@{
                    SamAccountName = "user"; DisplayName = "User"; Mail = $Mail
                    ExpiresOn = $today.AddDays($DaysLeft).AddHours(9); DaysLeft = $null; Threshold = $null; SentKey = $null
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = $null
                Status         = "Pending"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        Mock Write-Log {} -ModuleName PasswordExpiry
    }

    It "isn't due when the password has plenty of time left" {
        $user = New-TestUser 30
        Test-PasswordExpiry -PipelineObject $user -LogFile $logFile -Config $Config -SentLog @{} -Today $today
        $user.Status | Should -Be "NotDue"
    }

    It "sends the 7-day reminder with 5 days left (catches up if a run was missed)" {
        $user = New-TestUser 5
        Test-PasswordExpiry -PipelineObject $user -LogFile $logFile -Config $Config -SentLog @{} -Today $today
        $user.Status        | Should -Be "Due"
        $user.Raw.Threshold | Should -Be 7
    }

    It "doesn't send the same reminder twice" {
        $user = New-TestUser 5
        $sent = @{ "user|$($today.AddDays(5).ToString('yyyy-MM-dd'))|7" = "2026-09-18" }
        Test-PasswordExpiry -PipelineObject $user -LogFile $logFile -Config $Config -SentLog $sent -Today $today
        $user.Status | Should -Be "AlreadySent"
    }

    It "still sends the next reminder after an earlier one" {
        $user = New-TestUser 1
        $sent = @{ "user|$($today.AddDays(1).ToString('yyyy-MM-dd'))|7" = "2026-09-13" }
        Test-PasswordExpiry -PipelineObject $user -LogFile $logFile -Config $Config -SentLog $sent -Today $today
        $user.Status        | Should -Be "Due"
        $user.Raw.Threshold | Should -Be 1
    }

    It "marks already-expired passwords" {
        $user = New-TestUser -3
        Test-PasswordExpiry -PipelineObject $user -LogFile $logFile -Config $Config -SentLog @{} -Today $today
        $user.Status | Should -Be "Expired"
    }

    It "flags a due user with no email address" {
        $user = New-TestUser 1 -Mail ""
        Test-PasswordExpiry -PipelineObject $user -LogFile $logFile -Config $Config -SentLog @{} -Today $today
        $user.Status | Should -Be "Invalid"
    }
}
