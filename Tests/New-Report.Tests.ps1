Describe "New-Report" {

    BeforeAll {
        . "$PSScriptRoot\..\Modules\Shared\New-Report.ps1"

        function New-TestUser {
            param([string]$Sam, [string]$Status, [array]$Plan = @(), [array]$Errors = @())
            [pscustomobject]@{
                Raw    = [pscustomobject]@{ SamAccountName = $Sam }
                Status = $Status
                Plan   = $Plan
                Errors = $Errors
            }
        }
    }

    It "flags failed, not found and invalid users at the top" {
        $users = @(
            (New-TestUser "ok"      "Offboarded"),
            (New-TestUser "ghost"   "NotFound"),
            (New-TestUser "bad"     "Invalid" -Errors @("SamAccountName is invalid")),
            (New-TestUser "broken"  "Failed"  -Plan @(@{ Action = "RemoveLicenses"; Target = "broken@corp.com"; Result = "Failed" }) `
                                              -Errors @([pscustomobject]@{ Step = "RemoveLicenses"; Message = "Failed"; Exception = "Access denied" }))
        )

        $lines = New-Report -Users $users -ReportFile "TestDrive:\report.txt"

        $lines | Should -Contain "=== NEEDS ATTENTION (3) ==="
        $lines | Should -Contain "! ghost : NotFound"
        $lines | Should -Contain "    - SamAccountName is invalid"
        $lines | Should -Contain "    - RemoveLicenses -> broken@corp.com : FAILED"
        $lines | Should -Not -Contain "! ok : Offboarded"
    }

    It "has no attention section when everything worked" {
        $lines = New-Report -Users @(New-TestUser "ok" "Offboarded") -ReportFile "TestDrive:\report.txt"

        ($lines -join "`n") | Should -Not -Match "NEEDS ATTENTION"
    }
}
