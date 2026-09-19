function Get-ConditionalAccessAudit {
    [CmdletBinding()]
    param(
        # Where backups are kept (not under Reports/, so the 90-day cleanup doesn't delete them)
        [Parameter(Mandatory)]
        [string]$BackupFolder,

        [string]$LogFile
    )

    # Raw JSON from Graph so the backup can be used to recreate a policy exactly
    $policies = @()
    $uri = "v1.0/identity/conditionalAccess/policies"
    while ($uri) {
        $page = Invoke-MgGraphRequest -Method GET -Uri $uri -ErrorAction Stop
        $policies += @($page.value)
        $uri = $page.'@odata.nextLink'
    }

    # Compare with the most recent backup (if there is one)
    $null = New-Item -ItemType Directory -Path $BackupFolder -Force
    $lastFile = Get-ChildItem -Path $BackupFolder -Filter "policies_*.json" | Sort-Object Name | Select-Object -Last 1
    $previous = @{}
    if ($lastFile) {
        foreach ($policy in (Get-Content $lastFile.FullName -Raw | ConvertFrom-Json)) { $previous[$policy.id] = $policy }
    }

    # Save today's backup
    $backupFile = Join-Path $BackupFolder "policies_$(Get-Date -Format 'yyyyMMdd_HHmmss').json"
    ConvertTo-Json -InputObject @($policies) -Depth 20 | Out-File -FilePath $backupFile -Encoding utf8

    foreach ($policy in $policies) {
        $detail = "State: $($policy.state) | Modified: $($policy.modifiedDateTime)"

        if (-not $lastFile) {
            New-AuditFinding -Check "ConditionalAccess" -Name $policy.displayName -Detail "$detail | Baseline saved"
        }
        elseif (-not $previous.ContainsKey($policy.id)) {
            New-AuditFinding -Check "ConditionalAccess" -Name $policy.displayName -Detail $detail -Flagged $true -Reason "New policy since last backup"
        }
        # Graph updates modifiedDateTime on every edit, so a different value means the policy changed
        elseif ("$($previous[$policy.id].modifiedDateTime)" -ne "$($policy.modifiedDateTime)") {
            $was = $previous[$policy.id]
            $stateChange = if ($was.state -ne $policy.state) { " (state $($was.state) -> $($policy.state))" } else { "" }
            New-AuditFinding -Check "ConditionalAccess" -Name $policy.displayName -Detail $detail -Flagged $true `
                             -Reason "Changed since last backup$stateChange. Previous version: $($lastFile.Name)"
        }
        else {
            New-AuditFinding -Check "ConditionalAccess" -Name $policy.displayName -Detail $detail
        }
    }

    # Policies that disappeared
    $currentIds = @($policies | ForEach-Object { $_.id })
    foreach ($id in $previous.Keys | Where-Object { $_ -notin $currentIds }) {
        New-AuditFinding -Check "ConditionalAccess" -Name $previous[$id].displayName -Detail "Last seen in $($lastFile.Name)" `
                         -Flagged $true -Reason "Policy deleted since last backup (restore from $($lastFile.Name))"
    }
}
