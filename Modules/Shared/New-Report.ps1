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

    foreach ($user in $Users) {
        $name = "$($user.Raw.FirstName) $($user.Raw.LastName)"
        $validation = if ($user.Errors.Count -eq 0) { "PASS" } else { "FAIL" }
        $reportLines += "--- $name ---"
        $reportLines += "Validation: $validation"

        # Policy overview
        $reportLines += "Policy:"
        $reportLines += "  Distribution Lists: $($user.Raw.DistributionList -join '; ')"
        $reportLines += "  AD Groups: $($user.Raw.ADGroups -join '; ')"
        $reportLines += "  License: $($user.Raw.License)"

        # Planned actions + results
        $reportLines += "Onboarding Plan:"
        foreach ($step in $user.Plan) {
            $result = $step.Result ? $step.Result : "PENDING"
            $reportLines += "  $($step.Action): $result"
        }

        # User creation summary
        $reportLines += "User Creation: $($user.Status)"
        $reportLines += ""
    }

    # Aggregate summary
    $created       = ($Users | Where-Object Status -eq "Created").Count
    $alreadyExists = ($Users | Where-Object Status -eq "AlreadyExists").Count
    $failed        = ($Users | Where-Object Status -eq "Failed").Count
    $skipped       = ($Users | Where-Object Status -eq "Skipped").Count

    $reportLines += "=== Pipeline Summary ==="
    $reportLines += "Created: $created"
    $reportLines += "Already Exists: $alreadyExists"
    $reportLines += "Failed: $failed"
    $reportLines += "Skipped: $skipped"
    $reportLines += "`nReport generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"

    # Save to file
    $reportLines | Out-File -FilePath $ReportFile -Encoding utf8

    return $reportLines
}