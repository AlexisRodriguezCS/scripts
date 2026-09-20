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

    Context "Log files" {

        It "writes to a file named for today, not the plain name" {
            $log = Join-Path $TestDrive "Onboarding.log"
            $today = Get-Date -Format 'yyyy-MM-dd'

            Write-Log -Message "hello" -LogFile $log 6>$null

            Test-Path (Join-Path $TestDrive "Onboarding-$today.log") | Should -BeTrue
            Test-Path $log | Should -BeFalse
        }

        It "writes the same event as JSON beside it" {
            $log = Join-Path $TestDrive "Jsonl.log"
            $today = Get-Date -Format 'yyyy-MM-dd'

            Write-Log -Message "[a1b2c3d4] [New-OnboardingUser] CreateUser -> jdoe : CREATED" -Level "WARN" -LogFile $log 3>$null 6>$null

            $line = Get-Content (Join-Path $TestDrive "Jsonl-$today.jsonl") | Select-Object -Last 1 | ConvertFrom-Json

            $line.Level         | Should -Be "WARN"
            $line.CorrelationId | Should -Be "a1b2c3d4"
            $line.Step          | Should -Be "New-OnboardingUser"
            $line.Message       | Should -Be "CreateUser -> jdoe : CREATED"
            $line.RunId         | Should -Not -BeNullOrEmpty
        }

        It "gives every line of one run the same run id" {
            $log = Join-Path $TestDrive "Run.log"
            $today = Get-Date -Format 'yyyy-MM-dd'

            Write-Log -Message "first"  -LogFile $log 6>$null
            Write-Log -Message "second" -LogFile $log 6>$null

            $ids = Get-Content (Join-Path $TestDrive "Run-$today.jsonl") | ForEach-Object { ($_ | ConvertFrom-Json).RunId }
            ($ids | Select-Object -Unique).Count | Should -Be 1
        }

        It "still masks secrets in both files" {
            $log = Join-Path $TestDrive "Secret.log"
            $today = Get-Date -Format 'yyyy-MM-dd'
            $script:SecretValues = @("https://hooks.example.com/abc123")

            Write-Log -Message "posting to https://hooks.example.com/abc123 failed" -LogFile $log 6>$null

            Get-Content (Join-Path $TestDrive "Secret-$today.log")   | Should -Not -Match "abc123"
            Get-Content (Join-Path $TestDrive "Secret-$today.jsonl") | Should -Not -Match "abc123"

            $script:SecretValues = @()
        }
    }

    Context "Log retention" {

        It "deletes logs past the retention period, keeps recent ones" {
            $repo = Join-Path $TestDrive "repo"
            $logs = Join-Path $repo "Onboarding\Logs"
            $null = New-Item -ItemType Directory -Path $logs -Force
            $null = New-Item -ItemType Directory -Path (Join-Path $repo "Reports") -Force

            $old = New-Item -ItemType File -Path (Join-Path $logs "Onboarding-2024-01-01.log") -Force
            $oldJson = New-Item -ItemType File -Path (Join-Path $logs "Onboarding-2024-01-01.jsonl") -Force
            $new = New-Item -ItemType File -Path (Join-Path $logs "Onboarding-today.log") -Force
            $old.LastWriteTime     = (Get-Date).AddDays(-400)
            $oldJson.LastWriteTime = (Get-Date).AddDays(-400)

            & "$PSScriptRoot\..\Setup\Remove-OldReports.ps1" -Path (Join-Path $repo "Reports") -RepoPath $repo -LogDays 365 -Apply 6>$null

            Test-Path $old.FullName     | Should -BeFalse
            Test-Path $oldJson.FullName | Should -BeFalse
            Test-Path $new.FullName     | Should -BeTrue
        }
    }
}
