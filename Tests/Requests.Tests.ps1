Describe "ConvertTo-RequestRow" {

    BeforeAll {
        Remove-Module Requests -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\Requests\Requests.psm1" -Force
    }

    It "maps a new hire form to the onboarding row" {
        $row = ConvertTo-RequestRow -Fields @{ RequestType = "New hire"; FirstName = " Alex "; LastName = "Johnson"; JobTitle = "Accountant"; Department = "Finance"; Role = "Accountant" }

        $row.FirstName  | Should -Be "Alex"
        $row.Title      | Should -Be "Accountant"
        $row.Department | Should -Be "Finance"
    }

    It "maps a leaver form to the offboarding row" {
        $row = ConvertTo-RequestRow -Fields @{ RequestType = "Leaver"; Username = "jsmith"; ManagerEmail = "boss@corp.com" }

        $row.SamAccountName | Should -Be "jsmith"
        $row.Manager        | Should -Be "boss@corp.com"
    }

    It "maps a role change to the mover row" {
        $row = ConvertTo-RequestRow -Fields @{ RequestType = "Role change"; Username = "jsmith"; JobTitle = "Manager"; Department = "IT"; Role = "Admin"; ManagerUsername = "boss" }

        $row.SamAccountName | Should -Be "jsmith"
        $row.Manager        | Should -Be "boss"
    }

    It "keeps blanks blank on an info update so they aren't changed" {
        $row = ConvertTo-RequestRow -Fields @{ RequestType = "Update info"; Username = "jsmith"; MobilePhone = "555-0100" }

        $row.MobilePhone | Should -Be "555-0100"
        $row.Title       | Should -BeNullOrEmpty
    }

    It "rejects an unknown request type" {
        { ConvertTo-RequestRow -Fields @{ RequestType = "Promote to CEO" } } | Should -Throw "*Unknown request type*"
    }
}
