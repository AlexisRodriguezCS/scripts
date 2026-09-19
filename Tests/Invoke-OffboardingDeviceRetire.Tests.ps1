Describe "Invoke-OffboardingDeviceRetire" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module Offboarding -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Offboarding\Offboarding.psm1" -Force

        $identity = [pscustomobject]@{ SamAccountName = "jdoe"; EntraUPN = "jdoe@tenant.onmicrosoft.com" }
        Mock Write-Log {} -ModuleName Offboarding
    }

    BeforeEach {
        Mock Invoke-MgRetireDeviceManagementManagedDevice {} -ModuleName Offboarding
    }

    It "retires every device the leaver has" {
        Mock Get-MgUserManagedDevice {
            [pscustomobject]@{ Id = "1"; DeviceName = "LAPTOP-JD"; OperatingSystem = "Windows"; ManagedDeviceOwnerType = "company";  ManagementState = "managed" }
            [pscustomobject]@{ Id = "2"; DeviceName = "iPhone";    OperatingSystem = "iOS";     ManagedDeviceOwnerType = "personal"; ManagementState = "managed" }
        } -ModuleName Offboarding

        $result = Invoke-OffboardingDeviceRetire -Identity $identity -LogFile "TestDrive:\x.log"

        $result | Should -Match "Retire sent to 2 device"
        Should -Invoke Invoke-MgRetireDeviceManagementManagedDevice -ModuleName Offboarding -Times 2 -Exactly
    }

    It "doesn't send a second retire on a re-run" {
        Mock Get-MgUserManagedDevice {
            [pscustomobject]@{ Id = "1"; DeviceName = "LAPTOP-JD"; OperatingSystem = "Windows"; ManagedDeviceOwnerType = "company"; ManagementState = "retirePending" }
        } -ModuleName Offboarding

        $result = Invoke-OffboardingDeviceRetire -Identity $identity -LogFile "TestDrive:\x.log"

        $result | Should -Match "already pending"
        Should -Invoke Invoke-MgRetireDeviceManagementManagedDevice -ModuleName Offboarding -Times 0 -Exactly
    }

    It "reports when there are no devices" {
        Mock Get-MgUserManagedDevice { } -ModuleName Offboarding

        Invoke-OffboardingDeviceRetire -Identity $identity -LogFile "TestDrive:\x.log" | Should -Be "NoDevices"
    }
}
