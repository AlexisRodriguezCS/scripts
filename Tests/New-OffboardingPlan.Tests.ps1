Describe "New-OffboardingPlan" {

    BeforeAll {
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        function New-TestObject {
            param(
                [string]$Status = "Valid",
                [string]$DistinguishedName = "CN=John Doe,OU=IT,DC=corp,DC=local",
                [string]$Manager = ""
            )
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Raw            = [pscustomobject]@{ SamAccountName = "johndoe"; Manager = $Manager }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = [pscustomobject]@{
                    SamAccountName    = "johndoe"
                    DistinguishedName = $DistinguishedName
                    MemberOf          = @("CN=GRP-AllStaff,DC=corp,DC=local", "CN=GRP_ROLE_IT_User,DC=corp,DC=local")
                    EntraUPN          = "johndoe@tenant.onmicrosoft.com"
                }
                Status         = $Status
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        $Config  = [pscustomobject]@{ DisabledOU = "OU=Disabled,DC=corp,DC=local"; DefaultContact = "helpdesk@corp.com" }
        $logFile = "TestDrive:\offboarding.log"
        Mock Write-Log {} -ModuleName Offboarding
    }

    It "plans actions in a safe order: disable first, mailbox before licenses" {
        $obj = New-TestObject
        New-OffboardingPlan -PipelineObject $obj -LogFile $logFile -Config $Config

        $actions = $obj.Plan.Action
        $actions[0] | Should -Be "DisableAccount"
        $actions.IndexOf("ConvertMailbox") | Should -BeLessThan $actions.IndexOf("RemoveLicenses")
    }

    It "plans one group removal per group" {
        $obj = New-TestObject
        New-OffboardingPlan -PipelineObject $obj -LogFile $logFile -Config $Config

        @($obj.Plan | Where-Object { $_.Action -eq "RemoveFromGroup" }) | Should -HaveCount 2
    }

    It "skips the move when the user is already in the disabled OU" {
        $obj = New-TestObject -DistinguishedName "CN=John Doe,OU=Disabled,DC=corp,DC=local"
        New-OffboardingPlan -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Plan.Action | Should -Not -Contain "MoveToDisabledOU"
    }

    It "hands mailbox and OneDrive to the manager only when one is given" {
        $without = New-TestObject
        $with    = New-TestObject -Manager "manager@corp.com"
        New-OffboardingPlan -PipelineObject $without -LogFile $logFile -Config $Config
        New-OffboardingPlan -PipelineObject $with    -LogFile $logFile -Config $Config

        $without.Plan.Action | Should -Not -Contain "GrantMailboxAccess"
        $without.Plan.Action | Should -Not -Contain "ShareOneDrive"
        $with.Plan.Action    | Should -Contain "GrantMailboxAccess"
        $with.Plan.Action    | Should -Contain "ShareOneDrive"
    }

    It "points the out of office to the manager, or the default contact without one" {
        $without = New-TestObject
        $with    = New-TestObject -Manager "manager@corp.com"
        New-OffboardingPlan -PipelineObject $without -LogFile $logFile -Config $Config
        New-OffboardingPlan -PipelineObject $with    -LogFile $logFile -Config $Config

        ($without.Plan | Where-Object { $_.Action -eq "SetAutoReply" }).Target | Should -Be "helpdesk@corp.com"
        ($with.Plan    | Where-Object { $_.Action -eq "SetAutoReply" }).Target | Should -Be "manager@corp.com"
    }

    It "plans nothing for users that were not found" {
        $obj = New-TestObject -Status "NotFound"
        New-OffboardingPlan -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Plan | Should -HaveCount 0
    }
}
