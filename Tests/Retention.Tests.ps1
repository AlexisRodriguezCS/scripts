Describe "Retention" {

    BeforeAll {
        . "$PSScriptRoot\..\Modules\Shared\Write-Log.ps1"
    }

    Context "Remove-OldReports" {

        BeforeEach {
            $reports = "TestDrive:\Reports"
            $null = New-Item -ItemType Directory -Path "$reports\Snapshots\Offboarding_old", "$reports\Snapshots\Offboarding_new" -Force

            $oldFile = New-Item -ItemType File -Path "$reports\Snapshots\Offboarding_old\jdoe_before.json" -Force
            $newFile = New-Item -ItemType File -Path "$reports\Snapshots\Offboarding_new\jdoe_before.json" -Force
            $oldFile.LastWriteTime = (Get-Date).AddDays(-200)
        }

        It "only previews without -Apply" {
            & "$PSScriptRoot\..\Setup\Remove-OldReports.ps1" -Path $reports -Days 90 6>$null
            Test-Path "$reports\Snapshots\Offboarding_old\jdoe_before.json" | Should -BeTrue
        }

        It "deletes old files and their empty folders, keeps recent ones" {
            & "$PSScriptRoot\..\Setup\Remove-OldReports.ps1" -Path $reports -Days 90 -Apply 6>$null

            Test-Path "$reports\Snapshots\Offboarding_old" | Should -BeFalse
            Test-Path "$reports\Snapshots\Offboarding_new\jdoe_before.json" | Should -BeTrue
        }
    }

    Context "Log rotation" {

        It "rotates a log over 10 MB and keeps writing" {
            $log = "TestDrive:\big.log"
            [IO.File]::WriteAllBytes((Join-Path (Resolve-Path "TestDrive:\").Path "big.log"), [byte[]]::new(11MB))

            Write-Log -Message "after rotation" -LogFile $log 6>$null

            (Get-Item $log).Length | Should -BeLessThan 1KB
            @(Get-ChildItem "TestDrive:\big.log.*").Count | Should -Be 1
        }
    }
}
