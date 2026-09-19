Describe "MailboxQuota" {

    BeforeAll {
        . "$PSScriptRoot\Stubs.ps1"
        Remove-Module MailboxQuota -ErrorAction SilentlyContinue
        Import-Module "$PSScriptRoot\..\MailboxQuota\MailboxQuota.psm1" -Force

        $logFile = "TestDrive:\quota.log"
        $Config  = [pscustomobject]@{
            WarnAtPercent = @(80, 90, 95); SenderMailbox = "it@corp.com"
            EmailSubject = "Your mailbox is {Percent}% full"; EmailBody = "Hi {Name}, {Used} of {Quota} GB used."
        }
        Mock Write-Log {} -ModuleName MailboxQuota
    }

    It "reads byte counts from Exchange size strings" {
        InModuleScope MailboxQuota { ConvertTo-Bytes "49.5 GB (53,150,220,288 bytes)" } | Should -Be 53150220288
        InModuleScope MailboxQuota { ConvertTo-Bytes "Unlimited" } | Should -BeNullOrEmpty
    }

    Context "Full run" {

        BeforeEach {
            Mock Get-EXOMailbox {
                [pscustomobject]@{ UserPrincipalName = "full@corp.com";  DisplayName = "Full";  ProhibitSendQuota = "100 GB (107,374,182,400 bytes)" }
                [pscustomobject]@{ UserPrincipalName = "fine@corp.com";  DisplayName = "Fine";  ProhibitSendQuota = "100 GB (107,374,182,400 bytes)" }
                [pscustomobject]@{ UserPrincipalName = "nolimit@corp.com"; DisplayName = "None"; ProhibitSendQuota = "Unlimited" }
            } -ModuleName MailboxQuota
            Mock Get-EXOMailboxStatistics {
                $bytes = if ($Identity -eq "full@corp.com") { 99000000000 } else { 10000000000 }   # ~92% / ~9%
                [pscustomobject]@{ TotalItemSize = "x ($('{0:N0}' -f $bytes) bytes)" }
            } -ModuleName MailboxQuota
            Mock Send-MgUserMail {} -ModuleName MailboxQuota
            Mock New-Report {} -ModuleName MailboxQuota
        }

        It "warns only mailboxes over a level, at the highest level reached" {
            $result = Invoke-MailboxQuotaWarning -LogFile $logFile -Config $Config -SentLogPath (Join-Path $TestDrive "a.json") -Apply $true

            $result.Checked | Should -Be 2   # unlimited mailbox skipped
            $result.Sent    | Should -Be 1
            Should -Invoke Send-MgUserMail -ModuleName MailboxQuota -Times 1 -Exactly -ParameterFilter {
                $BodyParameter.Message.ToRecipients[0].EmailAddress.Address -eq "full@corp.com" -and $BodyParameter.Message.Subject -like "*92.2%*"
            }
        }

        It "doesn't email the same person twice in a month" {
            $sentLog = Join-Path $TestDrive "b.json"
            $null = Invoke-MailboxQuotaWarning -LogFile $logFile -Config $Config -SentLogPath $sentLog -Apply $true
            $second = Invoke-MailboxQuotaWarning -LogFile $logFile -Config $Config -SentLogPath $sentLog -Apply $true

            $second.Sent        | Should -Be 0
            $second.AlreadySent | Should -Be 1
            Should -Invoke Send-MgUserMail -ModuleName MailboxQuota -Times 1 -Exactly
        }

        It "sends nothing in a dry run" {
            $null = Invoke-MailboxQuotaWarning -LogFile $logFile -Config $Config -SentLogPath (Join-Path $TestDrive "c.json") -Apply $false
            Should -Invoke Send-MgUserMail -ModuleName MailboxQuota -Times 0 -Exactly
        }
    }
}
