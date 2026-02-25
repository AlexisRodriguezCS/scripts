<#
.SYNOPSIS
    Delete all users from Active Directory
.DESCRIPTION
    Safely removes all non-system user accounts for lab reset.
.NOTES
    Author: Alexis Rodriguez
    Date: 2026-02-9
#>

# Import Active Directory module
Import-Module ActiveDirectory

# Log file to track changes
$LogFile = "C:\Logs\Delete-AllNonSystemUsers-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
Import-Module "C:\Users\Techadmin\Documents\GitHub\scripts\Modules\Logger.psm1"
Write-Log "Script started" -LogFile $LogFile

# Define system accounts that should not be deleted
$systemAccounts = @(
    'Administrator',
    'Guest',
    'techadmin',
    'techadmin-admin',
    'svc_adscripts',
    'krbtgt'
)

# Get the users that arent system accounts
$users = Get-ADUser -Filter * | 
    Where-Object { $_.SamAccountName -notin $systemAccounts }

# Log header for clarity
Write-Log "=== USER AUDIT LIST BEGIN ===" -LogFile $LogFile

# Log each user BEFORE doing anything
foreach ($user in $users) {
    Write-Log "User: $($user.SamAccountName)" -LogFile $LogFile
}

# Log footer
Write-Log "=== USER AUDIT LIST END ===" -LogFile $LogFile



# Loop through users
foreach ($user in $users) {

    try {
        # Log what user is being processed
        Write-Log "Processing user $($user.SamAccountName)" -LogFile $LogFile

        # Delete user
        Remove-ADUser -Identity $user.DistinguishedName -Confirm:$false

        # Log success
        Write-Log "SUCCESS $($user.SamAccountName)" -LogFile $LogFile
    }
    catch {
        # Log any errors
        Write-Log "FAILED $($user.SamAccountName) : $($_.Exception.Message)" "ERROR" -LogFile $LogFile
    }
}

# Log script end
Write-Log "Script finished" -LogFile $LogFile