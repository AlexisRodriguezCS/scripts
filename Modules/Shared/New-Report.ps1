function New-Report {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Users,  # Array of pipeline objects

        [Parameter(Mandatory)]
        [string]$ReportFile        # File path for report output
    )

    $reportLines = @()
    $reportLines += "=== Pipeline Report ==="
    $reportLines += "Total Users: $($Users.Count)`n"

    # Anything that didn't finish cleanly goes at the top so it can't be missed
    $flagged = @($Users | Where-Object { $_.Status -in @("Failed","Invalid","NotFound","Stopped") })
    if ($flagged.Count -gt 0) {
        $reportLines += "=== NEEDS ATTENTION ($($flagged.Count)) ==="
        foreach ($user in $flagged) {
            $name = if ($user.Raw.SamAccountName) { $user.Raw.SamAccountName } else { "$($user.Raw.FirstName) $($user.Raw.LastName)" }
            $reportLines += "! $name : $($user.Status)"
            foreach ($err in $user.Errors) {
                # Validation errors are strings, pipeline errors are objects
                $reportLines += if ($err -is [string]) { "    - $err" } else { "    - $($err.Step): $($err.Message) $($err.Exception)" }
            }
            foreach ($step in $user.Plan | Where-Object { $_.Result -eq "Failed" }) {
                $reportLines += "    - $($step.Action) -> $($step.Target) : FAILED"
            }
        }
        $reportLines += ""
    }

    foreach ($user in $Users) {
        # Onboarding rows have first/last name, offboarding rows only have a SamAccountName
        $name = if ($user.Raw.SamAccountName) { $user.Raw.SamAccountName } else { "$($user.Raw.FirstName) $($user.Raw.LastName)" }
        $validation = if ($user.Errors.Count -eq 0) { "PASS" } else { "FAIL" }
        $reportLines += "--- $name ---"
        $reportLines += "Validation: $validation"

        # Policy overview (onboarding only)
        if ($user.Raw.PSObject.Properties["ADGroups"]) {
            $reportLines += "Policy:"
            $reportLines += "  Distribution Lists: $($user.Raw.DistributionList -join '; ')"
            $reportLines += "  AD Groups: $($user.Raw.ADGroups -join '; ')"
            $reportLines += "  License: $($user.Raw.License)"
        }

        # Planned actions + results
        $reportLines += "Plan:"
        foreach ($step in $user.Plan) {
            $result = if ($step.Result) { $step.Result } else { "PENDING" }
            $reportLines += "  $($step.Action): $result"
        }

        # Final status
        $reportLines += "Status: $($user.Status)"
        $reportLines += ""
    }

    # Aggregate summary (one line per final status)
    $reportLines += "=== Pipeline Summary ==="
    foreach ($group in $Users | Group-Object Status) {
        $reportLines += "$($group.Name): $($group.Count)"
    }
    $reportLines += "`nReport generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # Save to file
    $reportLines | Out-File -FilePath $ReportFile -Encoding utf8

    return $reportLines
}