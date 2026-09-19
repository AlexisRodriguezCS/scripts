Describe "Start-Offboarding" {

    BeforeAll {
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        function New-PlanItem {
            param([string]$Action, [string]$Target = "x")
            @{ Action = $Action; Target = $Target; Result = $null }
        }

        function New-TestObject {
            param(
                [string]$Status = "Valid",
                [array]$Plan = @()
            )
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Identity       = [pscustomobject]@{
                    SamAccountName    = "johndoe"
                    DistinguishedName = "CN=John Doe,OU=IT,DC=corp,DC=local"
                    EntraUPN          = "johndoe@tenant.onmicrosoft.com"
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = $Plan
                Status         = $Status
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        $Config  = [pscustomobject]@{ AutoReplyMessage = "{Name} has left. Contact {Contact}." }
        $logFile = "TestDrive:\offboarding.log"

        Mock Write-Log   {}           -ModuleName Offboarding
        Mock Start-Sleep {}           -ModuleName Offboarding
        Mock Get-Random  { return 1 } -ModuleName Offboarding
    }

    It "skips users that are not Valid" {
        Mock Disable-OffboardingAccount { "Disabled" } -ModuleName Offboarding

        $obj = New-TestObject -Status "NotFound" -Plan @(New-PlanItem "DisableAccount")
        Start-Offboarding -PipelineObject $obj -LogFile $logFile -Config $Config | Out-Null

        $obj.Status | Should -Be "NotFound"
        Should -Invoke Disable-OffboardingAccount -Times 0 -Exactly -ModuleName Offboarding
    }

    It "runs every action and marks the user Offboarded" {
        Mock Disable-OffboardingAccount    { "Disabled" }   -ModuleName Offboarding
        Mock Remove-OffboardingGroupMember { "Removed" }    -ModuleName Offboarding
        Mock Convert-OffboardingMailbox    { "Converted" }  -ModuleName Offboarding
        Mock Remove-OffboardingLicense     { "NoLicenses" } -ModuleName Offboarding

        $obj = New-TestObject -Plan @(
            (New-PlanItem "DisableAccount"),
            (New-PlanItem "RemoveFromGroup" "GRP-AllStaff"),
            (New-PlanItem "ConvertMailbox"),
            (New-PlanItem "RemoveLicenses")
        )
        Start-Offboarding -PipelineObject $obj -LogFile $logFile -Config $Config | Out-Null

        $obj.Status         | Should -Be "Offboarded"
        $obj.Plan[1].Result | Should -Be "Removed from GRP-AllStaff"
        $obj.Plan[3].Result | Should -Be "No licenses"
    }

    It "retries a failing action and succeeds" {
        $script:calls = 0
        Mock Remove-OffboardingGroupMember {
            $script:calls++
            if ($script:calls -lt 2) { throw "timeout" }
            "Removed"
        } -ModuleName Offboarding

        $obj = New-TestObject -Plan @(New-PlanItem "RemoveFromGroup" "GRP-AllStaff")
        Start-Offboarding -PipelineObject $obj -LogFile $logFile -Config $Config | Out-Null

        $obj.Status | Should -Be "Offboarded"
        Should -Invoke Start-Sleep -Times 1 -Exactly -ModuleName Offboarding
    }

    It "aborts without touching anything else if the account cannot be disabled" {
        Mock Disable-OffboardingAccount    { throw "Access denied" } -ModuleName Offboarding
        Mock Remove-OffboardingGroupMember { "Removed" }            -ModuleName Offboarding

        $obj = New-TestObject -Plan @(
            (New-PlanItem "DisableAccount"),
            (New-PlanItem "RemoveFromGroup" "GRP-AllStaff")
        )
        Start-Offboarding -PipelineObject $obj -LogFile $logFile -Config $Config | Out-Null

        $obj.Status | Should -Be "Failed"
        Should -Invoke Remove-OffboardingGroupMember -Times 0 -Exactly -ModuleName Offboarding
    }

    It "marks the user Failed but keeps going when a later action fails" {
        Mock Disable-OffboardingAccount { "Disabled" }               -ModuleName Offboarding
        Mock Convert-OffboardingMailbox { throw "Mailbox error" }    -ModuleName Offboarding
        Mock Remove-OffboardingLicense  { "Removed" }                -ModuleName Offboarding

        $obj = New-TestObject -Plan @(
            (New-PlanItem "DisableAccount"),
            (New-PlanItem "ConvertMailbox"),
            (New-PlanItem "RemoveLicenses")
        )
        Start-Offboarding -PipelineObject $obj -LogFile $logFile -Config $Config | Out-Null

        $obj.Status         | Should -Be "Failed"
        $obj.Plan[1].Result | Should -Be "Failed"
        Should -Invoke Remove-OffboardingLicense -Times 1 -Exactly -ModuleName Offboarding
    }
}
