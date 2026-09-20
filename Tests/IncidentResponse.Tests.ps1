Describe "IncidentResponse" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module IncidentResponse -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\IncidentResponse\IncidentResponse.psm1" -Force

        $logFile = "TestDrive:\incident.log"
        Mock Write-Log {} -ModuleName IncidentResponse
    }

    BeforeEach {
        Mock Get-MgUser {
            [pscustomobject]@{ Id = "id-1"; DisplayName = "Jane Doe"; UserPrincipalName = "jdoe@corp.com"; AccountEnabled = $true; OnPremisesSyncEnabled = $true; OnPremisesSamAccountName = "jdoe" }
        } -ModuleName IncidentResponse
        Mock Get-Mailbox { [pscustomobject]@{ ForwardingSmtpAddress = "smtp:attacker@evil.com"; ForwardingAddress = $null } } -ModuleName IncidentResponse
        Mock Get-InboxRule {
            [pscustomobject]@{ Name = "..."; Identity = "jdoe\1"; Enabled = $true; ForwardTo = $null; RedirectTo = $null; ForwardAsAttachmentTo = $null; DeleteMessage = $false; MoveToFolder = "RSS Feeds" }
            [pscustomobject]@{ Name = "Invoices"; Identity = "jdoe\2"; Enabled = $true; ForwardTo = $null; RedirectTo = $null; ForwardAsAttachmentTo = $null; DeleteMessage = $false; MoveToFolder = "Invoices" }
        } -ModuleName IncidentResponse
        Mock Get-MgAuditLogSignIn {
            [pscustomobject]@{ CreatedDateTime = (Get-Date); IPAddress = "1.2.3.4"; Location = [pscustomobject]@{ CountryOrRegion = "US" }; Status = [pscustomobject]@{ ErrorCode = 0 } }
            [pscustomobject]@{ CreatedDateTime = (Get-Date); IPAddress = "5.6.7.8"; Location = [pscustomobject]@{ CountryOrRegion = "NG" }; Status = [pscustomobject]@{ ErrorCode = 0 } }
        } -ModuleName IncidentResponse
        Mock Get-MgUserAuthenticationMethod {
            [pscustomobject]@{ Id = "m1"; AdditionalProperties = @{ '@odata.type' = "#microsoft.graph.phoneAuthenticationMethod"; createdDateTime = (Get-Date).AddDays(-1).ToString("o") } }
        } -ModuleName IncidentResponse

        Mock Get-MgUserOauth2PermissionGrant {
            # The user's own consent to a third-party app, and an admin consent for the whole tenant
            [pscustomobject]@{ Id = "g1"; ClientId = "app-evil"; ResourceId = "graph"; Scope = "Mail.Read offline_access"; ConsentType = "Principal" }
            [pscustomobject]@{ Id = "g2"; ClientId = "app-company"; ResourceId = "graph"; Scope = "User.Read"; ConsentType = "AllPrincipals" }
        } -ModuleName IncidentResponse
        Mock Remove-MgOauth2PermissionGrant {} -ModuleName IncidentResponse

        Mock Disable-ADAccount {} -ModuleName IncidentResponse
        Mock Set-ADUser {} -ModuleName IncidentResponse
        Mock Set-ADAccountPassword {} -ModuleName IncidentResponse
        Mock Update-MgUser {} -ModuleName IncidentResponse
        Mock Revoke-MgUserSignInSession {} -ModuleName IncidentResponse
        Mock Set-Mailbox {} -ModuleName IncidentResponse
        Mock Disable-InboxRule {} -ModuleName IncidentResponse
        Mock Save-UserSnapshot {} -ModuleName IncidentResponse
    }

    It "collects evidence but changes nothing in a dry run" {
        $result = Invoke-IncidentResponse -UserPrincipalName "jdoe@corp.com" -LogFile $logFile -Apply $false

        Test-Path (Join-Path $result.Evidence "sign-ins.csv")    | Should -BeTrue
        Test-Path (Join-Path $result.Evidence "inbox-rules.json") | Should -BeTrue
        Should -Invoke Disable-ADAccount -ModuleName IncidentResponse -Times 0 -Exactly
        Should -Invoke Set-Mailbox       -ModuleName IncidentResponse -Times 0 -Exactly
    }

    It "plans lock-out first, then forwarding, then only the suspicious rule" {
        $result = Invoke-IncidentResponse -UserPrincipalName "jdoe@corp.com" -LogFile $logFile -Apply $false

        $result.Plan[0] | Should -Match "^DisableAccount"
        $result.Plan[1] | Should -Match "^ResetPassword"
        $result.Plan[2] | Should -Match "^RevokeSessions"
        $result.Plan[3] | Should -Match "^RevokeAppConsents"
        $result.Plan[4] | Should -Match "^RemoveForwarding -> smtp:attacker@evil.com"
        @($result.Plan | Where-Object { $_ -like "DisableInboxRule*" }).Count | Should -Be 1   # the RSS one, not "Invoices"
    }

    It "contains a synced account in AD" {
        $result = Invoke-IncidentResponse -UserPrincipalName "jdoe@corp.com" -LogFile $logFile -Apply $true

        $result.Status | Should -Be "Contained"
        Should -Invoke Disable-ADAccount        -ModuleName IncidentResponse -Times 1 -Exactly
        Should -Invoke Set-ADAccountPassword    -ModuleName IncidentResponse -Times 1 -Exactly
        Should -Invoke Revoke-MgUserSignInSession -ModuleName IncidentResponse -Times 1 -Exactly
        Should -Invoke Disable-InboxRule        -ModuleName IncidentResponse -Times 1 -Exactly -ParameterFilter { $Identity -eq "jdoe\1" }
    }

    It "flags new MFA methods and sign-ins from several countries for a human" {
        $result = Invoke-IncidentResponse -UserPrincipalName "jdoe@corp.com" -LogFile $logFile -Apply $false

        ($result.FollowUp -join " ") | Should -Match "MFA method"
        ($result.FollowUp -join " ") | Should -Match "2 countries: NG, US"
    }

    It "revokes the user's own app consents, not the tenant's" {
        $result = Invoke-IncidentResponse -UserPrincipalName "jdoe@corp.com" -LogFile $logFile -Apply $true

        Test-Path (Join-Path $result.Evidence "oauth-grants.json") | Should -BeTrue
        Should -Invoke Remove-MgOauth2PermissionGrant -ModuleName IncidentResponse -Times 1 -Exactly -ParameterFilter { $OAuth2PermissionGrantId -eq "g1" }
        # g2 is an admin consent for everyone: pulling it would cut the whole company off that app
        Should -Invoke Remove-MgOauth2PermissionGrant -ModuleName IncidentResponse -Times 0 -Exactly -ParameterFilter { $OAuth2PermissionGrantId -eq "g2" }
    }

    It "skips the step when the user consented to nothing" {
        Mock Get-MgUserOauth2PermissionGrant { } -ModuleName IncidentResponse

        $result = Invoke-IncidentResponse -UserPrincipalName "jdoe@corp.com" -LogFile $logFile -Apply $true

        @($result.Plan | Where-Object { $_ -like "RevokeAppConsents*" }) | Should -BeNullOrEmpty
        Should -Invoke Remove-MgOauth2PermissionGrant -ModuleName IncidentResponse -Times 0 -Exactly
    }

    It "resets a cloud-only user's password in Entra" {
        Mock Get-MgUser {
            [pscustomobject]@{ Id = "id-2"; DisplayName = "Cloud User"; UserPrincipalName = "cloud@corp.com"; OnPremisesSyncEnabled = $false }
        } -ModuleName IncidentResponse

        $null = Invoke-IncidentResponse -UserPrincipalName "cloud@corp.com" -LogFile $logFile -Apply $true

        Should -Invoke Set-ADAccountPassword -ModuleName IncidentResponse -Times 0 -Exactly
        Should -Invoke Update-MgUser -ModuleName IncidentResponse -ParameterFilter { $PasswordProfile.ForceChangePasswordNextSignIn } -Times 1 -Exactly
    }
}
