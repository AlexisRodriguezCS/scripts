function Get-AdminAccountId {
    <#
        IDs of everyone holding a directory role (Global Admin, Helpdesk Admin, ...).

        Admin accounts are often used rarely and on purpose: a break-glass account may go
        untouched for a year by design. Disabling one because it looks idle is how a tenant
        gets locked out, so the review skips them and reports them instead.

        Read once per run, not per user.
    #>
    [CmdletBinding()]
    param(
        [string]$LogFile
    )

    $ids = [System.Collections.Generic.HashSet[string]]::new()

    # Only roles with at least one member are returned
    foreach ($role in Get-MgDirectoryRole -All -ErrorAction Stop) {
        foreach ($member in Get-MgDirectoryRoleMember -DirectoryRoleId $role.Id -All -ErrorAction Stop) {
            $null = $ids.Add("$($member.Id)")
        }
    }

    Write-Log -Message "[Get-AdminAccountId] $($ids.Count) account(s) hold an admin role; they are never disabled automatically" `
              -Level "INFO" -LogFile $LogFile

    return $ids
}
