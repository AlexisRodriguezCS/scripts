Describe "Get-OffboardingIdentity" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        function New-TestObject {
            param([string]$Status = "Valid")
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Raw            = [pscustomobject]@{ SamAccountName = "johndoe"; Manager = "" }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = $null
                Status         = $Status
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        $Config  = [pscustomobject]@{ TenantDomain = "tenant.onmicrosoft.com" }
        $logFile = "TestDrive:\offboarding.log"

        Mock Write-Log {}         -ModuleName Offboarding
        Mock Add-PipelineError {} -ModuleName Offboarding
    }

    It "builds the identity from AD" {
        Mock Get-ADUser {
            [pscustomobject]@{
                DisplayName       = "John Doe"
                DistinguishedName = "CN=John Doe,OU=IT,DC=corp,DC=local"
                MemberOf          = @("CN=GRP-AllStaff,DC=corp,DC=local")
            }
        } -ModuleName Offboarding

        $obj = New-TestObject
        Get-OffboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Status                     | Should -Be "Valid"
        $obj.Identity.DistinguishedName | Should -Be "CN=John Doe,OU=IT,DC=corp,DC=local"
        $obj.Identity.MemberOf          | Should -HaveCount 1
        $obj.Identity.EntraUPN          | Should -Be "johndoe@tenant.onmicrosoft.com"
    }

    It "refuses to offboard an AD admin from a request" {
        Mock Get-ADUser {
            [pscustomobject]@{ SamAccountName = "johndoe"; DistinguishedName = "CN=John Doe,OU=IT,DC=corp,DC=local"; MemberOf = @(); adminCount = 1 }
        } -ModuleName Offboarding

        $obj = New-TestObject
        Get-OffboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Status   | Should -Be "Invalid"
        $obj.Errors   | Should -Match "Protected account"
        $obj.Identity | Should -Be $null
    }

    It "sets status to NotFound when the user is not in AD" {
        Mock Get-ADUser { $null } -ModuleName Offboarding

        $obj = New-TestObject
        Get-OffboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Status   | Should -Be "NotFound"
        $obj.Identity | Should -Be $null
    }

    It "sets status to Failed when the AD lookup throws" {
        Mock Get-ADUser { throw "AD down" } -ModuleName Offboarding

        $obj = New-TestObject
        Get-OffboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        $obj.Status | Should -Be "Failed"
    }

    It "skips the lookup when validation failed" {
        Mock Get-ADUser {} -ModuleName Offboarding

        $obj = New-TestObject -Status "Invalid"
        Get-OffboardingIdentity -PipelineObject $obj -LogFile $logFile -Config $Config

        Should -Invoke Get-ADUser -Times 0 -Exactly -ModuleName Offboarding
    }
}
