Describe "New-RandomPassword" {

    BeforeAll {
        . "$PSScriptRoot\..\Modules\Shared\New-RandomPassword.ps1"
    }

    It "is the requested length" {
        (New-RandomPassword).Length           | Should -Be 16
        (New-RandomPassword -Length 32).Length | Should -Be 32
    }

    It "always meets AD complexity (upper, lower, digit, symbol)" {
        foreach ($i in 1..50) {
            $p = New-RandomPassword -Length 12
            $p | Should -MatchExactly '[A-Z]'
            $p | Should -MatchExactly '[a-z]'
            $p | Should -Match '[0-9]'
            $p | Should -Match '[^A-Za-z0-9]'
        }
    }

    It "never uses look-alike characters" {
        foreach ($i in 1..50) {
            New-RandomPassword | Should -Not -MatchExactly '[0O1lI]'
        }
    }

    It "is different every time" {
        New-RandomPassword | Should -Not -Be (New-RandomPassword)
    }

    It "rejects lengths too short to be safe" {
        { New-RandomPassword -Length 8 } | Should -Throw
    }
}
