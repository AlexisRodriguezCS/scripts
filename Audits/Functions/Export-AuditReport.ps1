function Export-AuditReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Check,

        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [PSCustomObject[]]$Findings,

        [Parameter(Mandatory)]
        [string]$ReportDir,

        [Parameter(Mandatory)]
        [string]$RunStamp
    )

    $null = New-Item -ItemType Directory -Path $ReportDir -Force
    $csvFile = "$ReportDir\Audit_$($Check)_$RunStamp.csv"
    $txtFile = "$ReportDir\Audit_$($Check)_$RunStamp.txt"

    # Full data for Excel
    $Findings | Export-Csv -Path $csvFile -NoTypeInformation

    # Short summary for people, problems first
    $flagged = @($Findings | Where-Object Flagged)
    $lines = @("=== $Check Audit ===", "Checked: $($Findings.Count)", "")

    if ($flagged.Count -gt 0) {
        $lines += "=== NEEDS ATTENTION ($($flagged.Count)) ==="
        $lines += $flagged | ForEach-Object { "! $($_.Name) : $($_.Reason)  [$($_.Detail)]" }
    } else {
        $lines += "Nothing needs attention."
    }

    $lines += "", "Full list: $csvFile", "Report generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $lines | Out-File -FilePath $txtFile -Encoding utf8

    return [pscustomobject]@{
        Check      = $Check
        Checked    = $Findings.Count
        Flagged    = $flagged.Count
        ReportFile = $txtFile
        CsvFile    = $csvFile
    }
}
