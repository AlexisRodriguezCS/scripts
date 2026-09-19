Describe "Remove-OffboardingCloudGroupMember" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        $identity = [pscustomobject]@{ SamAccountName = "jdoe"; EntraUPN = "jdoe@corp.com" }

        function New-Group([string]$Id, [string]$Name, [string[]]$Types = @(), [bool]$Security = $false, [bool]$Mail = $true, [bool]$Synced = $false) {
            [pscustomobject]@{ Id = $Id; AdditionalProperties = @{
                '@odata.type' = "#microsoft.graph.group"; displayName = $Name; groupTypes = $Types
                securityEnabled = $Security; mailEnabled = $Mail; onPremisesSyncEnabled = $Synced } }
        }

        Mock Write-Log {} -ModuleName Offboarding
    }

    BeforeEach {
        Mock Get-MgUser { [pscustomobject]@{ Id = $(if ($UserId -eq "boss@corp.com") { "boss-id" } else { "jdoe-id" }) } } -ModuleName Offboarding
        Mock Get-MgUserMemberOf {
            New-Group "t1" "Project X Team" @("Unified")
            New-Group "s1" "App Access" @() $true $false
            New-Group "d1" "Sales (dynamic)" @("Unified", "DynamicMembership")
            New-Group "a1" "GRP-AllStaff (from AD)" @() $true $false $true
            New-Group "m1" "All Staff DL" @() $false $true
            [pscustomobject]@{ Id = "r1"; AdditionalProperties = @{ '@odata.type' = "#microsoft.graph.directoryRole"; displayName = "Some role" } }
        } -ModuleName Offboarding
        Mock Get-MgGroupOwner { if ($GroupId -eq "t1") { [pscustomobject]@{ Id = "jdoe-id" } } else { [pscustomobject]@{ Id = "someone-else" } } } -ModuleName Offboarding
        Mock Remove-MgGroupMemberByRef {} -ModuleName Offboarding
        Mock Remove-MgGroupOwnerByRef {} -ModuleName Offboarding
        Mock New-MgGroupOwnerByRef {} -ModuleName Offboarding
    }

    It "removes only from Teams/M365 and plain cloud security groups" {
        $result = Remove-OffboardingCloudGroupMember -Identity $identity -Manager "boss@corp.com" -LogFile "TestDrive:\x.log"

        $result | Should -Match "Removed from 2"
        Should -Invoke Remove-MgGroupMemberByRef -ModuleName Offboarding -Times 2 -Exactly
        Should -Invoke Remove-MgGroupMemberByRef -ModuleName Offboarding -Times 0 -Exactly -ParameterFilter { $GroupId -in @("d1", "a1", "m1") }
    }

    It "makes the manager owner before removing a sole owner" {
        $null = Remove-OffboardingCloudGroupMember -Identity $identity -Manager "boss@corp.com" -LogFile "TestDrive:\x.log"

        Should -Invoke New-MgGroupOwnerByRef -ModuleName Offboarding -Times 1 -Exactly -ParameterFilter {
            # The real Graph module (if installed) turns the hashtable into its own type, so check the serialized body
            $GroupId -eq "t1" -and ($BodyParameter | ConvertTo-Json -Depth 5) -like "*directoryObjects/boss-id*"
        }
        Should -Invoke Remove-MgGroupOwnerByRef -ModuleName Offboarding -Times 1 -Exactly -ParameterFilter { $GroupId -eq "t1" }
    }

    It "flags teams left without an owner when no manager is given" {
        $result = Remove-OffboardingCloudGroupMember -Identity $identity -LogFile "TestDrive:\x.log"

        $result | Should -Match "NO OWNER LEFT.*Project X Team"
        Should -Invoke New-MgGroupOwnerByRef -ModuleName Offboarding -Times 0 -Exactly
    }

    It "reports when there are no cloud groups" {
        Mock Get-MgUserMemberOf { New-Group "a1" "From AD" @() $true $false $true } -ModuleName Offboarding
        Remove-OffboardingCloudGroupMember -Identity $identity -LogFile "TestDrive:\x.log" | Should -Be "NoCloudGroups"
    }
}
