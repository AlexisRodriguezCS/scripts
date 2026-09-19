Describe "Restore from snapshot" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Rollback -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Rollback\Rollback.psm1" -Force

        $logFile  = "TestDrive:\rollback.log"
        $snapshot = Join-Path $TestDrive "jdoe_before.json"

        # Before offboarding: enabled, in IT OU, two groups, a title
        [ordered]@{
            Stage = "Before"; TakenAt = "2026-09-19T10:00:00"; SamAccountName = "jdoe"
            AD = [ordered]@{
                Enabled = $true; DistinguishedName = "CN=Jane Doe,OU=IT,DC=corp,DC=local"
                Title = "Engineer"; Department = "IT"; Manager = $null; Description = $null
                MemberOf = @("CN=GRP-AllStaff,DC=corp,DC=local", "CN=GRP_ROLE_IT_User,DC=corp,DC=local")
            }
            Entra   = @{ LicenseSkuIds = @("sku-e3") }
            Mailbox = @{ Type = "UserMailbox" }
        } | ConvertTo-Json -Depth 5 | Out-File $snapshot

        Mock Write-Log {} -ModuleName Rollback
    }

    BeforeEach {
        # After offboarding: disabled, in Disabled OU, no groups, one extra group added by mistake
        Mock Get-ADUser {
            [pscustomobject]@{
                Enabled = $false; DistinguishedName = "CN=Jane Doe,OU=Disabled,DC=corp,DC=local"
                Title = "Engineer"; Department = "IT"; Manager = $null; Description = "Offboarded 2026-09-19"
                MemberOf = @("CN=GRP-Leavers,DC=corp,DC=local")
            }
        } -ModuleName Rollback
        Mock Enable-ADAccount {} -ModuleName Rollback
        Mock Add-ADGroupMember {} -ModuleName Rollback
        Mock Remove-ADGroupMember {} -ModuleName Rollback
        Mock Move-ADObject {} -ModuleName Rollback
        Mock Set-ADUser {} -ModuleName Rollback
        Mock New-Report {} -ModuleName Rollback
    }

    It "plans only the difference, enable first and OU move last" {
        $user = New-RestorePlan -SnapshotFile $snapshot
        $actions = @($user.Plan | ForEach-Object { "$($_.Action):$($_.Target)" })

        $actions[0]  | Should -Be "EnableAccount:jdoe"
        $actions[-1] | Should -Be "MoveToOU:OU=IT,DC=corp,DC=local"
        $actions     | Should -Contain "AddToGroup:CN=GRP-AllStaff,DC=corp,DC=local"
        $actions     | Should -Contain "AddToGroup:CN=GRP_ROLE_IT_User,DC=corp,DC=local"
        $actions     | Should -Contain "RemoveFromGroup:CN=GRP-Leavers,DC=corp,DC=local"
        ($actions -join " ") | Should -Not -Match "SetAttribute:Title"   # unchanged
    }

    It "lists licenses and mailbox type for a human" {
        $user = New-RestorePlan -SnapshotFile $snapshot
        ($user.Manual -join " ") | Should -Match "sku-e3"
        ($user.Manual -join " ") | Should -Match "UserMailbox"
    }

    It "restores everything with -Apply" {
        $result = Invoke-RestoreFromSnapshot -SnapshotFile $snapshot -LogFile $logFile -Apply $true

        $result.Status | Should -Be "Restored"
        Should -Invoke Enable-ADAccount  -ModuleName Rollback -Times 1 -Exactly
        Should -Invoke Add-ADGroupMember -ModuleName Rollback -Times 2 -Exactly
        Should -Invoke Move-ADObject     -ModuleName Rollback -Times 1 -Exactly -ParameterFilter { $TargetPath -eq "OU=IT,DC=corp,DC=local" }
    }

    It "changes nothing in a preview" {
        $null = Invoke-RestoreFromSnapshot -SnapshotFile $snapshot -LogFile $logFile -Apply $false
        Should -Invoke Enable-ADAccount -ModuleName Rollback -Times 0 -Exactly
    }

    It "reports NoChange when the user already matches the snapshot" {
        Mock Get-ADUser {
            [pscustomobject]@{
                Enabled = $true; DistinguishedName = "CN=Jane Doe,OU=IT,DC=corp,DC=local"; Title = "Engineer"; Department = "IT"
                MemberOf = @("CN=GRP-AllStaff,DC=corp,DC=local", "CN=GRP_ROLE_IT_User,DC=corp,DC=local")
            }
        } -ModuleName Rollback

        (New-RestorePlan -SnapshotFile $snapshot).Status | Should -Be "NoChange"
    }
}
