Describe "InactiveAccounts" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module InactiveAccounts -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\InactiveAccounts\InactiveAccounts.psm1" -Force

        $logFile = "TestDrive:\inactive.log"
        $now     = [datetime]"2026-09-19"
        $Config  = [pscustomobject]@{
            MemberInactiveDays  = 90
            GuestInactiveDays   = 60
            ExcludeAccounts     = @("breakglass@corp.com")
            MaxPercentToDisable = 10
        }

        function New-TestUser {
            param([string]$Upn, [string]$Type = "Member", $LastSignIn, $Created = "2020-01-01")
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Raw            = [pscustomobject]@{
                    SamAccountName = $Upn; Id = [guid]::NewGuid(); UPN = $Upn; DisplayName = $Upn; UserType = $Type
                    Synced = $false; OnPremSam = $null; CreatedDate = [datetime]$Created
                    LastSignIn = $(if ($LastSignIn) { [datetime]$LastSignIn }); DaysInactive = $null; Reason = $null
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = [pscustomobject]@{ SamAccountName = $null; EntraUPN = $Upn }
                Status         = "Pending"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        Mock Write-Log {} -ModuleName InactiveAccounts
    }

    Context "Test-InactiveAccount" {

        It "flags a member with no sign-in for over 90 days" {
            $user = New-TestUser "old@corp.com" -LastSignIn "2026-05-01"
            Test-InactiveAccount -PipelineObject $user -LogFile $logFile -Config $Config -Now $now
            $user.Status | Should -Be "Inactive"
        }

        It "leaves a recently active member alone" {
            $user = New-TestUser "active@corp.com" -LastSignIn "2026-09-01"
            Test-InactiveAccount -PipelineObject $user -LogFile $logFile -Config $Config -Now $now
            $user.Status | Should -Be "Active"
        }

        It "uses the shorter guest threshold" {
            $user = New-TestUser "vendor@other.com" -Type "Guest" -LastSignIn "2026-07-01"
            Test-InactiveAccount -PipelineObject $user -LogFile $logFile -Config $Config -Now $now
            $user.Status | Should -Be "Inactive"
        }

        It "doesn't catch a new hire who hasn't signed in yet" {
            $user = New-TestUser "newhire@corp.com" -Created "2026-09-10"
            Test-InactiveAccount -PipelineObject $user -LogFile $logFile -Config $Config -Now $now
            $user.Status | Should -Be "Active"
        }

        It "flags an old account that never signed in" {
            $user = New-TestUser "never@corp.com" -Created "2025-01-01"
            Test-InactiveAccount -PipelineObject $user -LogFile $logFile -Config $Config -Now $now
            $user.Status     | Should -Be "Inactive"
            $user.Raw.Reason | Should -Match "Never signed in"
        }

        It "never touches excluded accounts" {
            $user = New-TestUser "breakglass@corp.com" -LastSignIn "2020-01-01"
            Test-InactiveAccount -PipelineObject $user -LogFile $logFile -Config $Config -Now $now
            $user.Status | Should -Be "Excluded"
        }
    }

    Context "New-InactiveAccountPlan" {

        It "disables members and removes guests" {
            $member = New-TestUser "m@corp.com"; $member.Status = "Inactive"
            $guest  = New-TestUser "g@other.com" -Type "Guest"; $guest.Status = "Inactive"

            New-InactiveAccountPlan -PipelineObject $member -LogFile $logFile
            New-InactiveAccountPlan -PipelineObject $guest  -LogFile $logFile

            $member.Plan[0].Action | Should -Be "DisableAccount"
            $guest.Plan[0].Action  | Should -Be "RemoveGuest"
        }
    }

    Context "Safety stop" {

        It "changes nothing if too much of the tenant looks inactive" {
            # 5 of 10 inactive = 50%, well over the 10% limit
            $users = @(1..5 | ForEach-Object { New-TestUser "old$_@corp.com" -LastSignIn "2025-01-01" }) +
                     @(1..5 | ForEach-Object { New-TestUser "new$_@corp.com" -LastSignIn (Get-Date).AddDays(-1) })
            Mock Get-InactiveAccountData { $users } -ModuleName InactiveAccounts
            Mock Start-InactiveAccountCleanup {} -ModuleName InactiveAccounts
            Mock New-Report {} -ModuleName InactiveAccounts
            Mock Export-Csv {} -ModuleName InactiveAccounts

            $result = Invoke-InactiveAccountReview -LogFile $logFile -Config $Config -Apply $true

            Should -Invoke Start-InactiveAccountCleanup -ModuleName InactiveAccounts -Times 0 -Exactly
            $result.Failed | Should -Be 5
        }
    }
}
