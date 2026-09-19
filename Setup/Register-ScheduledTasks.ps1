#Requires -Version 7.0
#Requires -RunAsAdministrator
<#
    One-time setup on the server that runs the scripts: creates the Windows scheduled tasks.

    .\Setup\Register-ScheduledTasks.ps1 -Client "ClientA" -RunAs "CONTOSO\svc-automation$"

    RunAs should be a group Managed Service Account (gMSA, ends with $) so there is no password to store or rotate.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Client,

    [Parameter(Mandatory)]
    [string]$RunAs,

    [string]$TaskFolder = "\IdentityAutomation\"
)

$root = Resolve-Path "$PSScriptRoot\.."
$pwsh = (Get-Command pwsh).Source

# Name -> script, arguments, schedule
$tasks = @(
    @{ Name = "HR request queue";          Script = "Requests\Invoke-RequestQueue.ps1";      Args = "-Apply"; Trigger = New-ScheduledTaskTrigger -Once -At "6:00" -RepetitionInterval (New-TimeSpan -Minutes 15) }
    @{ Name = "Password expiry reminders"; Script = "PasswordExpiry\PasswordExpiry.ps1";     Args = "-Apply"; Trigger = New-ScheduledTaskTrigger -Daily -At "8:00" }
    @{ Name = "Inactive accounts review";  Script = "InactiveAccounts\InactiveAccounts.ps1"; Args = "";       Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "7:00" }
    @{ Name = "Stale devices review";      Script = "StaleDevices\StaleDevices.ps1";         Args = "";       Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "7:15" }
    @{ Name = "Weekly audits";             Script = "Audits\Audit.ps1";                      Args = "";       Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Monday -At "7:30" }
    @{ Name = "Delete old reports";        Script = "Setup\Remove-OldReports.ps1";           Args = "-Apply"; Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At "3:00"; NoClient = $true }
)

# gMSA accounts log on as a service with no stored password
$principal = New-ScheduledTaskPrincipal -UserId $RunAs -LogonType Password -RunLevel Highest
$settings  = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Hours 2) -MultipleInstances IgnoreNew -StartWhenAvailable

# [0] = normal task, [1] = task that takes no -Client (e.g. report cleanup)
$clientArg = @("-Client `"$Client`"", "")

foreach ($task in $tasks) {
    $action = New-ScheduledTaskAction -Execute $pwsh -WorkingDirectory $root `
              -Argument ("-NoProfile -NonInteractive -File `"$root\$($task.Script)`" " + $clientArg[[bool]$task.NoClient] + " $($task.Args)")

    # Re-running this script updates the tasks instead of failing
    $null = Register-ScheduledTask -TaskPath $TaskFolder -TaskName "$($task.Name) ($Client)" -Action $action `
                                   -Trigger $task.Trigger -Principal $principal -Settings $settings -Force

    Write-Host "Registered: $($task.Name) ($Client)" -ForegroundColor Green
}

Write-Host "`nInactive accounts and audits run review-only. Add -Apply to the inactive accounts task once you trust the results."
