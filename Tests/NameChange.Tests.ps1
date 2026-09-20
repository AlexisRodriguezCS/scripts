Describe "NameChange" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module NameChange -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\NameChange\NameChange.psm1" -Force

        $logFile = "TestDrive:\namechange.log"
        $Config  = [pscustomobject]@{ TenantDomain = "tenant.onmicrosoft.com" }

        Mock Write-Log {} -ModuleName NameChange
    }

    BeforeEach {
        Mock Get-ADUser {
            [pscustomobject]@{
                SamAccountName    = "jsmith"
                GivenName         = "Jane"
                Surname           = "Smith"
                DisplayName       = "Jane Smith"
                DistinguishedName = "CN=Jane Smith,OU=Sales,DC=corp,DC=local"
                UserPrincipalName = "jsmith@corp.com"
                EmailAddress      = "jsmith@corp.com"
                proxyAddresses    = @("SMTP:jsmith@corp.com", "smtp:jane.smith@corp.com")
                adminCount        = $null
            }
        } -ModuleName NameChange -ParameterFilter { $Filter -like "*jsmith*" }
        Mock Get-ADUser { $null } -ModuleName NameChange
        Mock Set-ADUser {} -ModuleName NameChange
        Mock Rename-ADObject {} -ModuleName NameChange
        Mock Invoke-EntraSync {} -ModuleName NameChange
        Mock Save-UserSnapshot {} -ModuleName NameChange
        Mock New-Report {} -ModuleName NameChange
        Mock New-Item {} -ModuleName NameChange
    }

    Context "Validation" {

        It "rejects a request that changes nothing" {
            $result = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith" }) `
                                            -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "Invalid"
            $result.Users[0].Errors | Should -Match "Nothing to change"
        }

        It "rejects a name with characters AD can't store" {
            $result = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Smith, Jr" }) `
                                            -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "Invalid"
        }

        It "refuses to take a username someone else already has" {
            Mock Get-ADUser { [pscustomobject]@{ SamAccountName = "taken" } } -ModuleName NameChange -ParameterFilter { $Filter -like "*taken*" }

            $result = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Johnson"; NewUsername = "taken" }) `
                                            -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "Invalid"
            $result.Users[0].Errors | Should -Match "already taken"
        }

        It "refuses an admin account unless IT allows it" {
            Mock Get-ADUser {
                [pscustomobject]@{ SamAccountName = "jsmith"; GivenName = "Jane"; Surname = "Smith"; DisplayName = "Jane Smith"
                                   DistinguishedName = "CN=Jane Smith,DC=corp,DC=local"; UserPrincipalName = "jsmith@corp.com"
                                   proxyAddresses = @(); adminCount = 1 }
            } -ModuleName NameChange -ParameterFilter { $Filter -like "*jsmith*" }

            $result = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Johnson" }) `
                                            -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "Invalid"
            $result.Users[0].Errors | Should -Match "Protected account"
        }
    }

    Context "Name only" {

        It "renames the account and leaves the username alone" {
            $result = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Johnson" }) `
                                            -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status  | Should -Be "Renamed"
            $result.Users[0].NewName | Should -Be "Jane Johnson"

            Should -Invoke Set-ADUser -ModuleName NameChange -Times 1 -Exactly -ParameterFilter {
                $Surname -eq "Johnson" -and $DisplayName -eq "Jane Johnson"
            }
            Should -Invoke Rename-ADObject -ModuleName NameChange -Times 1 -Exactly -ParameterFilter { $NewName -eq "Jane Johnson" }
            # No new username means no sign-in change and no new email address
            Should -Invoke Set-ADUser -ModuleName NameChange -Times 0 -Exactly -ParameterFilter { $SamAccountName }
        }

        It "reports NoChange when the name already matches" {
            $result = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Smith" }) `
                                            -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status | Should -Be "NoChange"
            Should -Invoke Rename-ADObject -ModuleName NameChange -Times 0 -Exactly
        }

        It "changes nothing in a dry run" {
            $null = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Johnson" }) `
                                          -LogFile $logFile -Config $Config -Apply $false

            Should -Invoke Set-ADUser -ModuleName NameChange -Times 0 -Exactly
            Should -Invoke Rename-ADObject -ModuleName NameChange -Times 0 -Exactly
        }
    }

    Context "Username and email" {

        It "changes the sign-in name and makes the new address primary" {
            $result = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Johnson"; NewUsername = "jjohnson" }) `
                                            -LogFile $logFile -Config $Config -Apply $true

            $result.Users[0].Status      | Should -Be "Renamed"
            $result.Users[0].NewUsername | Should -Be "jjohnson"

            Should -Invoke Set-ADUser -ModuleName NameChange -Times 1 -Exactly -ParameterFilter {
                $SamAccountName -eq "jjohnson" -and $UserPrincipalName -eq "jjohnson@corp.com"
            }
            Should -Invoke Set-ADUser -ModuleName NameChange -Times 1 -Exactly -ParameterFilter {
                $Replace -and $Replace.proxyAddresses[0] -eq "SMTP:jjohnson@corp.com"
            }
        }

        It "keeps the old address as an alias so mail still arrives" {
            $null = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Johnson"; NewUsername = "jjohnson" }) `
                                          -LogFile $logFile -Config $Config -Apply $true

            Should -Invoke Set-ADUser -ModuleName NameChange -Times 1 -Exactly -ParameterFilter {
                $Replace -and "smtp:jsmith@corp.com" -in $Replace.proxyAddresses
            }
        }

        It "drops the old address when the request says so" {
            $null = Invoke-UserNameChange -LogFile $logFile -Config $Config -Apply $true `
                -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Johnson"; NewUsername = "jjohnson"; KeepOldEmail = "No" })

            Should -Invoke Set-ADUser -ModuleName NameChange -Times 1 -Exactly -ParameterFilter {
                $Replace -and "smtp:jsmith@corp.com" -notin $Replace.proxyAddresses
            }
        }

        It "pushes the change to Microsoft 365 straight away" {
            $null = Invoke-UserNameChange -Requests @([pscustomobject]@{ SamAccountName = "jsmith"; NewLastName = "Johnson" }) `
                                          -LogFile $logFile -Config $Config -Apply $true

            Should -Invoke Invoke-EntraSync -ModuleName NameChange -Times 1 -Exactly
        }
    }
}
