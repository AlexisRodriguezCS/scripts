function Get-AccessReview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        # Folder for the per-manager review sheets
        [Parameter(Mandatory)]
        [string]$OutputFolder,

        [string]$LogFile
    )

    $users = Get-ADUser -Filter "Enabled -eq 'True'" -SearchBase $Config.DefaultOU `
                        -Properties DisplayName, Manager, MemberOf -ErrorAction Stop

    $managerNames = @{}   # Manager DN -> display name, looked up once each
    $entries = [System.Collections.Generic.List[object]]::new()

    foreach ($user in $users) {
        if (-not $user.Manager) {
            New-AuditFinding -Check "AccessReview" -Name $user.SamAccountName -Detail "$(@($user.MemberOf).Count) groups" `
                             -Flagged $true -Reason "No manager set, nobody can review this access"
            continue
        }

        if (-not $managerNames.ContainsKey($user.Manager)) {
            $managerNames[$user.Manager] = (Get-ADUser -Identity $user.Manager -Properties DisplayName -ErrorAction SilentlyContinue).DisplayName
        }

        foreach ($groupDn in $user.MemberOf) {
            $entries.Add([pscustomobject]@{
                Manager  = $managerNames[$user.Manager]
                Employee = $user.DisplayName
                Username = $user.SamAccountName
                Access   = ($groupDn -split '(?<!\\),')[0] -replace '^CN='
                Decision = ""        # Manager fills in: Keep / Remove
            })
        }
    }

    # One sheet per manager so each only sees their own team
    $null = New-Item -ItemType Directory -Path $OutputFolder -Force

    foreach ($sheet in $entries | Group-Object Manager) {
        $file = Join-Path $OutputFolder "AccessReview_$($sheet.Name -replace '[^\w\- ]', '').csv"
        $sheet.Group | Export-Csv -Path $file -NoTypeInformation

        New-AuditFinding -Check "AccessReview" -Name $sheet.Name -Detail "$($sheet.Count) access entries to review -> $file"
    }
}
