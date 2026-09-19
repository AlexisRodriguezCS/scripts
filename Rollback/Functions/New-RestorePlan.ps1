function New-RestorePlan {
    [CmdletBinding()]
    param(
        # A *_before.json snapshot written by Save-UserSnapshot
        [Parameter(Mandatory)]
        [string]$SnapshotFile,

        [string]$LogFile
    )

    $snapshot = Get-Content $SnapshotFile -Raw | ConvertFrom-Json
    if (-not $snapshot.AD) { throw "Snapshot has no AD data to restore: $SnapshotFile" }

    $sam    = $snapshot.SamAccountName
    $before = $snapshot.AD

    $current = Get-ADUser -Filter "SamAccountName -eq '$sam'" `
                          -Properties Enabled, Title, Department, Manager, Description, MemberOf, DistinguishedName -ErrorAction Stop
    if (-not $current) { throw "$sam no longer exists in AD; it can't be restored from a snapshot (check the AD Recycle Bin)" }

    $plan = @()

    # 1. Account back on first, so nothing else is wasted on a disabled account
    if ($before.Enabled -and -not $current.Enabled) {
        $plan += @{ Action = "EnableAccount"; Target = $sam; Result = $null }
    }

    # 2. Attributes (empty values in the snapshot are skipped: AD can't "set" an empty value)
    $desired = @{}
    foreach ($attribute in "Title", "Department", "Manager", "Description") {
        if ($before.$attribute) { $desired[$attribute] = "$($before.$attribute)" }
    }
    $plan += @(Get-UserAttributeChanges -Current $current -Desired $desired)

    # 3. Groups: back to exactly what the snapshot had
    $beforeGroups  = @($before.MemberOf)
    $currentGroups = @($current.MemberOf)
    foreach ($group in $beforeGroups | Where-Object { $_ -notin $currentGroups }) {
        $plan += @{ Action = "AddToGroup"; Target = $group; Result = $null }
    }
    foreach ($group in $currentGroups | Where-Object { $_ -notin $beforeGroups }) {
        $plan += @{ Action = "RemoveFromGroup"; Target = $group; Result = $null }
    }

    # 4. OU last: moving changes the DN the other steps use
    $beforeOu  = $before.DistinguishedName -replace '^CN=.+?(?<!\\),'
    $currentOu = $current.DistinguishedName -replace '^CN=.+?(?<!\\),'
    if ($beforeOu -ne $currentOu) {
        $plan += @{ Action = "MoveToOU"; Target = $beforeOu; Result = $null }
    }

    # Things AD can't restore: listed for a human
    $manual = @()
    if ($snapshot.Entra.LicenseSkuIds) { $manual += "Licenses before: $($snapshot.Entra.LicenseSkuIds -join ', ') (reassign in Microsoft 365 if they were removed)" }
    if ($snapshot.Mailbox.Type)         { $manual += "Mailbox type before: $($snapshot.Mailbox.Type) (convert back if it was changed to shared)" }

    [pscustomobject]@{
        CorrelationId = [guid]::NewGuid().ToString()
        Raw      = [pscustomobject]@{ SamAccountName = $sam; Snapshot = $SnapshotFile; TakenAt = $snapshot.TakenAt }
        Identity = [pscustomobject]@{ SamAccountName = $sam; DistinguishedName = $current.DistinguishedName }
        Errors   = [System.Collections.Generic.List[object]]::new()
        Plan     = $plan
        Manual   = $manual
        Status   = if ($plan.Count) { "Valid" } else { "NoChange" }
        StepsCompleted = [System.Collections.Generic.HashSet[string]]::new()
        StepDurations  = @{}
    }
}
