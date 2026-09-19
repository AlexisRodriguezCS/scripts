Describe "Mover" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Mover -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Mover\Mover.psm1" -Force

        $logFile = "TestDrive:\mover.log"
        $Config  = [pscustomobject]@{
            DefaultOU               = "OU=Employees,DC=corp,DC=local"
            TenantDomain            = "tenant.onmicrosoft.com"
            DefaultDistributionList = "AllStaff"
            DistributionLists       = @("AllStaff", "Managers", "Finance", "IT")
            DefaultGroups           = @("GRP-AllStaff")
            DefaultLicense          = "M365"
            Departments             = @("Finance", "IT")
        }
        Mock Write-Log {} -ModuleName Mover
    }

    Context "New-MoverPlan (IT tech -> Finance accountant)" {

        BeforeAll {
            Mock Get-ADUser {
                [pscustomobject]@{
                    DistinguishedName = "CN=Lisa Taylor,OU=IT,OU=Employees,DC=corp,DC=local"
                    DisplayName = "Lisa Taylor"; Title = "Technician"; Department = "IT"; Manager = $null
                    MemberOf = @(
                        "CN=GRP_ROLE_IT_Helpdesk,OU=Groups,DC=corp,DC=local",
                        "CN=GRP-AllStaff,OU=Groups,DC=corp,DC=local",
                        "CN=Project-X,OU=Groups,DC=corp,DC=local"
                    )
                }
            } -ModuleName Mover

            $script:user = New-MoverRequest -Row ([pscustomobject]@{ SamAccountName = "lisataylor"; Title = "Accountant"; Department = "finance"; Role = "Accountant" }) -LogFile $logFile
            Test-MoverData -PipelineObject $user -LogFile $logFile -Config $Config
            Get-MoverIdentity -PipelineObject $user -LogFile $logFile -Config $Config
            Set-OnboardingPolicy -PipelineObject $user -LogFile $logFile -Config $Config
            New-MoverPlan -PipelineObject $user -LogFile $logFile -Config $Config
            $script:actions = @($user.Plan | ForEach-Object { "$($_.Action):$($_.Target)" })
        }

        It "uses the configured department spelling" {
            $user.Raw.Department | Should -Be "Finance"
        }

        It "updates title and department" {
            $actions | Should -Contain "SetAttribute:Title"
            $actions | Should -Contain "SetAttribute:Department"
        }

        It "adds the new role group and removes the old one" {
            $actions | Should -Contain "AddToGroup:GRP_ROLE_Finance_User"
            $actions | Should -Contain "RemoveFromGroup:CN=GRP_ROLE_IT_Helpdesk,OU=Groups,DC=corp,DC=local"
        }

        It "leaves groups outside the role prefix alone" {
            ($actions -join ' ') | Should -Not -Match "Project-X"
            ($actions -join ' ') | Should -Not -Match "GRP-AllStaff"
        }

        It "moves to the new department OU after group changes" {
            $actions | Should -Contain "MoveToDepartmentOU:OU=Finance,OU=Employees,DC=corp,DC=local"
            $moveIndex = [array]::IndexOf($actions, "MoveToDepartmentOU:OU=Finance,OU=Employees,DC=corp,DC=local")
            $removeIndex = [array]::IndexOf($actions, "RemoveFromGroup:CN=GRP_ROLE_IT_Helpdesk,OU=Groups,DC=corp,DC=local")
            $removeIndex | Should -BeLessThan $moveIndex
        }

        It "syncs the department DL but never the all-staff list" {
            $sync = $user.Plan | Where-Object { $_.Action -eq "SyncDistributionLists" }
            $sync.Target | Should -Be "Finance"
        }
    }

    Context "Test-MoverData" {

        It "rejects a department that doesn't exist" {
            $user = New-MoverRequest -Row ([pscustomobject]@{ SamAccountName = "x"; Title = "T"; Department = "Space"; Role = "User" }) -LogFile $logFile
            Test-MoverData -PipelineObject $user -LogFile $logFile -Config $Config

            $user.Status | Should -Be "Invalid"
        }
    }

    Context "Sync-MoverDLMembership" {

        BeforeEach {
            Mock Get-Mailbox { [pscustomobject]@{ DistinguishedName = "CN=lisa" } } -ModuleName Mover
            Mock Get-Recipient { @([pscustomobject]@{ Name = "IT" }, [pscustomobject]@{ Name = "AllStaff" }, [pscustomobject]@{ Name = "Book Club" }) } -ModuleName Mover
            Mock Add-DistributionGroupMember {} -ModuleName Mover
            Mock Remove-DistributionGroupMember {} -ModuleName Mover
        }

        It "adds the new list, removes the old managed one, keeps everything else" {
            $identity = [pscustomobject]@{ EntraUPN = "lisa@tenant.onmicrosoft.com" }

            $result = InModuleScope Mover -Parameters @{ identity = $identity; Config = $Config } {
                param($identity, $Config)
                Sync-MoverDLMembership -Identity $identity -Target "Finance" -Config $Config -LogFile "TestDrive:\x.log"
            }

            $result | Should -Be "Added: Finance | Removed: IT"
            Should -Invoke Add-DistributionGroupMember    -ModuleName Mover -Times 1 -Exactly -ParameterFilter { $Identity -eq "Finance" }
            Should -Invoke Remove-DistributionGroupMember -ModuleName Mover -Times 1 -Exactly -ParameterFilter { $Identity -eq "IT" }
        }
    }
}
