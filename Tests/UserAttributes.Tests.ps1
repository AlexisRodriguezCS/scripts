Describe "UserAttributes" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module UserAttributes -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\UserAttributes\UserAttributes.psm1" -Force

        $logFile = "TestDrive:\attributes.log"
        $Config  = [pscustomobject]@{ TenantDomain = "tenant.onmicrosoft.com" }
        Mock Write-Log {} -ModuleName UserAttributes
    }

    Context "Get-UserAttributeChanges" {

        It "only plans attributes that actually change" {
            $current = [pscustomobject]@{ Title = "Accountant"; Department = "Finance" }

            $changes = @(InModuleScope UserAttributes -Parameters @{ current = $current } {
                param($current)
                Get-UserAttributeChanges -Current $current -Desired @{ Title = "Senior Accountant"; Department = "Finance" }
            })

            $changes.Count     | Should -Be 1
            $changes[0].Target | Should -Be "Title"
            $changes[0].Old    | Should -Be "Accountant"
            $changes[0].Value  | Should -Be "Senior Accountant"
        }

        It "treats a casing fix as a change" {
            $current = [pscustomobject]@{ Department = "it" }

            $changes = @(InModuleScope UserAttributes -Parameters @{ current = $current } {
                param($current)
                Get-UserAttributeChanges -Current $current -Desired @{ Department = "IT" }
            })

            $changes.Count | Should -Be 1
        }
    }

    Context "Full run" {

        BeforeEach {
            Mock Get-ADUser {
                [pscustomobject]@{ DistinguishedName = "CN=John,OU=IT,DC=corp,DC=local"; DisplayName = "John"; Title = "Tech"; Department = "IT"; Manager = $null }
            } -ModuleName UserAttributes -ParameterFilter { $Filter -like "*johndoe*" }
            Mock Get-ADUser {
                [pscustomobject]@{ DistinguishedName = "CN=Mary,OU=IT,DC=corp,DC=local" }
            } -ModuleName UserAttributes -ParameterFilter { $Filter -like "*marysmith*" }
            Mock Get-ADUser { $null } -ModuleName UserAttributes -ParameterFilter { $Filter -like "*ghost*" }
            Mock Set-ADUser {} -ModuleName UserAttributes
            Mock Save-UserSnapshot {} -ModuleName UserAttributes
        }

        It "updates only what changed and resolves the manager to a DN" {
            $row = [pscustomobject]@{ SamAccountName = "johndoe"; Title = "Senior Tech"; Department = "IT"; Manager = "marysmith" }

            $result = Invoke-UserAttributesUpdate -Requests @($row) -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "Updated"
            Should -Invoke Set-ADUser -ModuleName UserAttributes -Times 2 -Exactly
            Should -Invoke Set-ADUser -ModuleName UserAttributes -Times 1 -Exactly -ParameterFilter { $Manager -eq "CN=Mary,OU=IT,DC=corp,DC=local" }
        }

        It "reports NoChange and changes nothing when values already match" {
            $row = [pscustomobject]@{ SamAccountName = "johndoe"; Title = "Tech" }

            $result = Invoke-UserAttributesUpdate -Requests @($row) -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "NoChange"
            Should -Invoke Set-ADUser -ModuleName UserAttributes -Times 0 -Exactly
        }

        It "flags an unknown user" {
            $result = Invoke-UserAttributesUpdate -Requests @([pscustomobject]@{ SamAccountName = "ghost"; Title = "X" }) -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "NotFound"
            $result.Failed          | Should -Be 1
        }

        It "rejects a request with nothing to change" {
            $result = Invoke-UserAttributesUpdate -Requests @([pscustomobject]@{ SamAccountName = "johndoe"; Title = "" }) -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "Invalid"
            $result.Users[0].Errors | Should -Match "No attributes to change"
        }

        It "changes nothing in a dry run" {
            $row = [pscustomobject]@{ SamAccountName = "johndoe"; Title = "Senior Tech" }

            $null = Invoke-UserAttributesUpdate -Requests @($row) -LogFile $logFile -Config $Config -Apply $false

            Should -Invoke Set-ADUser -ModuleName UserAttributes -Times 0 -Exactly
        }
    }

    Context "Set-UserAttribute log line" {

        It "says what the value was, not just that it updated" {
            Mock Set-ADUser {} -ModuleName UserAttributes

            $result = InModuleScope UserAttributes {
                $identity = [pscustomobject]@{ DistinguishedName = "CN=John,DC=corp,DC=local" }
                Set-UserAttribute -Identity $identity -Attribute "Title" -Value "Senior Tech" -Old "Tech" -LogFile "TestDrive:\x.log"
            }

            $result | Should -Be "'Tech' is now 'Senior Tech'"
        }

        It "says (empty) when there was nothing there before" {
            Mock Set-ADUser {} -ModuleName UserAttributes

            $result = InModuleScope UserAttributes {
                $identity = [pscustomobject]@{ DistinguishedName = "CN=John,DC=corp,DC=local" }
                Set-UserAttribute -Identity $identity -Attribute "OfficePhone" -Value "555-0142" -Old "" -LogFile "TestDrive:\x.log"
            }

            $result | Should -Be "(empty) is now '555-0142'"
        }
    }

    Context "Protected accounts" {

        BeforeEach {
            Mock Get-ADUser {
                [pscustomobject]@{ SamAccountName = "admin"; DistinguishedName = "CN=Admin,DC=corp,DC=local"; DisplayName = "Admin"; Title = "Tech"; adminCount = 1 }
            } -ModuleName UserAttributes
            Mock Set-ADUser {} -ModuleName UserAttributes
            Mock Save-UserSnapshot {} -ModuleName UserAttributes
        }

        It "refuses to edit an AD admin" {
            $result = Invoke-UserAttributesUpdate -Requests @([pscustomobject]@{ SamAccountName = "admin"; Title = "Boss" }) `
                                                 -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "Invalid"
            $result.Users[0].Errors | Should -Match "Protected account"
            Should -Invoke Set-ADUser -ModuleName UserAttributes -Times 0 -Exactly
        }

        It "lets IT through with -AllowProtected" {
            $result = Invoke-UserAttributesUpdate -Requests @([pscustomobject]@{ SamAccountName = "admin"; Title = "Boss" }) `
                                                 -LogFile $logFile -Apply $true `
                                                 -Config ([pscustomobject]@{ TenantDomain = "tenant.onmicrosoft.com"; AllowProtected = $true })

            $result.Users[0].Status | Should -Be "Updated"
            Should -Invoke Set-ADUser -ModuleName UserAttributes -Times 1 -Exactly
        }
    }
}
