Describe "New-OnboardingUser" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Onboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Onboarding\Onboarding.psm1" -Force

        function New-TestObject {
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Identity       = [pscustomobject]@{
                    FirstName         = "John"
                    LastName          = "Doe"
                    DisplayName       = "John Doe"
                    SamAccountName    = "jdoe"
                    UserPrincipalName = "jdoe@corp.local"
                    OU                = "OU=IT,DC=corp,DC=local"
                    EntraUPN          = "jdoe@tenant.onmicrosoft.com"
                    EmployeeID        = "E100"
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Status         = "Valid"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        $script:logFile = "$PSScriptRoot\..\Onboarding\Logs\Testing\New-OnboardingUser_test.txt"

        Mock Write-Log {}          -ModuleName Onboarding
        Mock Add-PipelineError {}  -ModuleName Onboarding
    }

    It "sets status to AlreadyExists when user already exists in AD" {
        Mock Get-ADUser { return @{ SamAccountName = "jdoe"; EmployeeID = "E100" } } -ModuleName Onboarding
        Mock New-ADUser {}                                       -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status              | Should -Be "AlreadyExists"
        $obj.StepsCompleted      | Should -Contain "New-OnboardingUser"
        Should -Invoke New-ADUser -Times 0 -ModuleName Onboarding
    }

    It "creates user and sets status to Created when user does not exist" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status              | Should -Be "Created"
        $obj.StepsCompleted      | Should -Contain "New-OnboardingUser"
        Should -Invoke New-ADUser -Times 1 -ModuleName Onboarding
    }

    It "gives a different person with the same name the next free username" {
        Mock Get-ADUser { @{ SamAccountName = "jdoe"; EmployeeID = "E001" } } -ModuleName Onboarding -ParameterFilter { $Filter -like "*'jdoe'*" }
        Mock Get-ADUser { $null } -ModuleName Onboarding -ParameterFilter { $Filter -like "*'jdoe2'*" }
        Mock New-ADUser {} -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status                     | Should -Be "Created"
        $obj.Identity.SamAccountName    | Should -Be "jdoe2"
        $obj.Identity.UserPrincipalName | Should -Be "jdoe2@corp.local"
        $obj.Identity.EntraUPN          | Should -Be "jdoe2@tenant.onmicrosoft.com"
        Should -Invoke New-ADUser -Times 1 -Exactly -ModuleName Onboarding -ParameterFilter { $SamAccountName -eq "jdoe2" -and $EmployeeID -eq "E100" }
    }

    It "refuses to guess when the username is taken and there is no Employee ID" {
        Mock Get-ADUser { @{ SamAccountName = "jdoe" } } -ModuleName Onboarding
        Mock New-ADUser {} -ModuleName Onboarding

        $obj = New-TestObject
        $obj.Identity.EmployeeID = $null
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Failed"
        Should -Invoke New-ADUser -Times 0 -Exactly -ModuleName Onboarding
    }

    It "does not run step twice if already completed" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        $obj.StepsCompleted.Add("New-OnboardingUser") | Out-Null

        $before = $obj.Status
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be $before
        Should -Invoke New-ADUser -Times 0 -ModuleName Onboarding
    }

    It "does not run step if pipeline status is already Failed" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        $obj.Status = "Failed"

        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Failed"
        Should -Invoke New-ADUser -Times 0 -ModuleName Onboarding
    }

    It "does not run step if pipeline status is already Invalid" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        $obj.Status = "Invalid"

        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Invalid"
        Should -Invoke New-ADUser -Times 0 -ModuleName Onboarding
    }

    It "sets status to Failed when AD lookup throws" {
        Mock Get-ADUser { throw "AD down" } -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Failed"
        Should -Invoke Add-PipelineError -Times 1 -ModuleName Onboarding
    }

    It "sets status to Failed when New-ADUser throws" {
        Mock Get-ADUser { return $null }           -ModuleName Onboarding
        Mock New-ADUser { throw "Creation failed" } -ModuleName Onboarding

        $obj = New-TestObject
        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        $obj.Status | Should -Be "Failed"
        Should -Invoke Add-PipelineError -Times 1 -ModuleName Onboarding
    }

    It "sets DisplayName, not just the object name" {
        # Without it the person is blank in Outlook, Teams and the address book
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        New-OnboardingUser -PipelineObject (New-TestObject) -LogFile $script:logFile

        Should -Invoke New-ADUser -Times 1 -Exactly -ModuleName Onboarding -ParameterFilter {
            $DisplayName -eq "John Doe" -and $Name -eq "John Doe"
        }
    }

    It "creates the account with the details HR gave: title, department, manager, office" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        $obj = New-TestObject
        $obj.Identity | Add-Member Title      "Accountant" -Force
        $obj.Identity | Add-Member Department "Finance"    -Force
        $obj.Identity | Add-Member Office     "Chicago"    -Force
        $obj.Identity | Add-Member Company    "Contoso"    -Force
        $obj.Identity | Add-Member ManagerDN  "CN=Boss,DC=corp,DC=local" -Force

        New-OnboardingUser -PipelineObject $obj -LogFile $script:logFile

        Should -Invoke New-ADUser -Times 1 -Exactly -ModuleName Onboarding -ParameterFilter {
            $Title -eq "Accountant" -and $Department -eq "Finance" -and
            $Office -eq "Chicago" -and $Company -eq "Contoso" -and $Manager -eq "CN=Boss,DC=corp,DC=local"
        }
    }

    It "leaves out the details HR didn't fill in (AD rejects empty values)" {
        Mock Get-ADUser { return $null } -ModuleName Onboarding
        Mock New-ADUser {}               -ModuleName Onboarding

        # New-TestObject has no Title / Department / Manager
        New-OnboardingUser -PipelineObject (New-TestObject) -LogFile $script:logFile

        Should -Invoke New-ADUser -Times 1 -Exactly -ModuleName Onboarding -ParameterFilter {
            -not $PSBoundParameters.ContainsKey("Title") -and -not $PSBoundParameters.ContainsKey("Manager")
        }
    }
}