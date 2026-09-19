function Get-LicenseAudit {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [string]$LogFile,
        # Injectable for tests
        [datetime]$Now = (Get-Date)
    )

    $inactiveDays = if ($Config.InactiveDays) { $Config.InactiveDays } else { 90 }

    # Graph has no prices; they come from config (monthly, per license): { "SPE_E3": 36.00, ... }
    function Get-Price([string]$sku) {
        $price = $Config.LicensePrices.$sku
        if ($price) { [double]$price } else { 0 }
    }

    $skus = @(Get-MgSubscribedSku -All -ErrorAction Stop)
    $skuNames = @{}
    foreach ($sku in $skus) { $skuNames["$($sku.SkuId)"] = $sku.SkuPartNumber }

    # Per license type: bought vs assigned
    foreach ($sku in $skus) {
        $bought = [int]$sku.PrepaidUnits.Enabled
        $used   = [int]$sku.ConsumedUnits
        $unused = $bought - $used
        $price  = Get-Price $sku.SkuPartNumber

        New-AuditFinding -Check "Licenses" -Name $sku.SkuPartNumber `
                         -Detail "Bought: $bought | Assigned: $used | Unused: $unused | Monthly: $('{0:C}' -f ($bought * $price))" `
                         -Flagged ($unused -gt 0 -and $price -gt 0) `
                         -Reason $(if ($unused -gt 0 -and $price -gt 0) { "$unused unused, wasting $('{0:C}' -f ($unused * $price))/month" })
    }

    # Per user: licenses on accounts nobody uses (needs signInActivity: Entra ID P1 + AuditLog.Read.All)
    $users = Get-MgUser -All -Property "id,userPrincipalName,department,accountEnabled,assignedLicenses,signInActivity" -ErrorAction Stop
    $byDepartment = @{}

    foreach ($user in $users | Where-Object { $_.AssignedLicenses }) {
        $names = @($user.AssignedLicenses | ForEach-Object { $skuNames["$($_.SkuId)"] })
        $cost  = ($names | ForEach-Object { Get-Price $_ } | Measure-Object -Sum).Sum

        $department = if ($user.Department) { $user.Department } else { "(no department)" }
        if (-not $byDepartment.ContainsKey($department)) { $byDepartment[$department] = @{ Users = 0; Cost = 0 } }
        $byDepartment[$department].Users++
        $byDepartment[$department].Cost += $cost

        $lastSignIn = $user.SignInActivity.LastSuccessfulSignInDateTime
        if (-not $lastSignIn) { $lastSignIn = $user.SignInActivity.LastSignInDateTime }

        $reason = if (-not $user.AccountEnabled) { "License on a disabled account" }
                  elseif ($lastSignIn -and ($Now - [datetime]$lastSignIn).TotalDays -gt $inactiveDays) { "License on an account unused for $inactiveDays+ days" }

        if ($reason) {
            New-AuditFinding -Check "Licenses" -Name $user.UserPrincipalName `
                             -Detail "$($names -join ', ') | $('{0:C}' -f $cost)/month" -Flagged $true -Reason $reason
        }
    }

    # Cost per department (for finance)
    foreach ($department in $byDepartment.Keys | Sort-Object) {
        New-AuditFinding -Check "LicenseCostByDepartment" -Name $department `
                         -Detail "$($byDepartment[$department].Users) users | $('{0:C}' -f $byDepartment[$department].Cost)/month"
    }
}
