Describe "StaleDevices" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module StaleDevices -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\StaleDevices\StaleDevices.psm1" -Force

        $logFile = "TestDrive:\devices.log"
        $now     = [datetime]"2026-09-19"
        $Config  = [pscustomobject]@{ RetireAfterDays = 90; DeleteAfterDays = 180; ExcludeDevices = @("LOBBY-KIOSK"); MaxPercentToChange = 20 }

        function New-TestDevice {
            param([string]$Name, [int]$DaysAgo, [string]$State = "managed")
            [pscustomobject]@{
                CorrelationId  = [guid]::NewGuid().ToString()
                Raw            = [pscustomobject]@{
                    SamAccountName = $Name; Id = [guid]::NewGuid(); DeviceName = $Name; OS = "Windows"; Owner = "u@corp.com"
                    OwnerType = "company"; LastSync = $now.AddDays(-$DaysAgo); Compliance = "compliant"
                    ManagementState = $State; Serial = "SN1"; DaysSinceSync = $null
                }
                Errors         = [System.Collections.Generic.List[object]]::new()
                Plan           = @()
                Identity       = $null
                Status         = "Pending"
                StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
                StepDurations  = @{}
            }
        }

        function Invoke-Decide($device) {
            Test-StaleDevice -PipelineObject $device -LogFile $logFile -Config $Config -Now $now
            New-StaleDevicePlan -PipelineObject $device -LogFile $logFile -Config $Config
        }

        Mock Write-Log {} -ModuleName StaleDevices
    }

    It "leaves devices that checked in recently alone" {
        $d = New-TestDevice "LAPTOP-1" 10; Invoke-Decide $d
        $d.Status | Should -Be "Active"
        $d.Plan   | Should -HaveCount 0
    }

    It "treats a device that never checked in as stale" {
        $d = New-TestDevice "NEVER-1" 0
        $d.Raw.LastSync = $null
        Invoke-Decide $d

        $d.Status         | Should -Be "Stale"
        $d.Plan[0].Action | Should -Be "DeleteRecord"
        $d.Errors         | Should -HaveCount 0
    }

    It "retires a device not seen for 90+ days" {
        $d = New-TestDevice "LAPTOP-2" 120; Invoke-Decide $d
        $d.Plan[0].Action | Should -Be "Retire"
    }

    It "doesn't send a second retire to a device that's already pending" {
        $d = New-TestDevice "LAPTOP-3" 120 -State "retirePending"; Invoke-Decide $d
        $d.Plan | Should -HaveCount 0
    }

    It "deletes the record once the device is very old" {
        $d = New-TestDevice "LAPTOP-4" 200 -State "retirePending"; Invoke-Decide $d
        $d.Plan[0].Action | Should -Be "DeleteRecord"
    }

    It "never touches excluded devices" {
        $d = New-TestDevice "LOBBY-KIOSK" 400; Invoke-Decide $d
        $d.Status | Should -Be "Excluded"
    }

    It "stops everything when too many devices look stale" {
        $devices = @(1..5 | ForEach-Object { New-TestDevice "OLD-$_" 300 }) + @(1..5 | ForEach-Object { New-TestDevice "NEW-$_" 1 })
        # Real Get-Date is used inside the run, so shift the fake dates to "now"
        $devices | ForEach-Object { $_.Raw.LastSync = (Get-Date).AddDays(-(($now - $_.Raw.LastSync).TotalDays)) }
        Mock Get-DeviceData { $devices } -ModuleName StaleDevices
        Mock Invoke-MgRetireDeviceManagementManagedDevice {} -ModuleName StaleDevices
        Mock Remove-MgDeviceManagementManagedDevice {} -ModuleName StaleDevices
        Mock New-Report {} -ModuleName StaleDevices
        Mock Export-Csv {} -ModuleName StaleDevices

        $result = Invoke-StaleDeviceCleanup -LogFile $logFile -Config $Config -Apply $true

        $result.Failed | Should -Be 5
        Should -Invoke Remove-MgDeviceManagementManagedDevice -ModuleName StaleDevices -Times 0 -Exactly
    }

    It "retires and deletes when under the safety limit" {
        $devices = @((New-TestDevice "OLD-1" 120), (New-TestDevice "OLD-2" 300)) + @(1..10 | ForEach-Object { New-TestDevice "NEW-$_" 1 })
        $devices | ForEach-Object { $_.Raw.LastSync = (Get-Date).AddDays(-(($now - $_.Raw.LastSync).TotalDays)) }
        Mock Get-DeviceData { $devices } -ModuleName StaleDevices
        Mock Invoke-MgRetireDeviceManagementManagedDevice {} -ModuleName StaleDevices
        Mock Remove-MgDeviceManagementManagedDevice {} -ModuleName StaleDevices
        Mock New-Report {} -ModuleName StaleDevices
        Mock Export-Csv {} -ModuleName StaleDevices

        $result = Invoke-StaleDeviceCleanup -LogFile $logFile -Config $Config -Apply $true

        $result.Retired | Should -Be 1
        $result.Deleted | Should -Be 1
    }
}
