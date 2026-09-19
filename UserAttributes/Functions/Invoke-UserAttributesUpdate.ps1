function Invoke-UserAttributesUpdate {
    [CmdletBinding()]
    param(
        # One or more rows (from a CSV, or built from parameters for a single person)
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Requests,
        [Parameter(Mandatory)]
        [string]$LogFile,
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,
        [bool]$Apply
    )

    $runStamp  = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir = "$PSScriptRoot\..\..\Reports"

    # 1. Build requests
    $users = @($Requests | ForEach-Object { New-UserAttributesRequest -Row $_ -LogFile $LogFile })

    foreach ($user in $users) {
        # 2. Validate
        Test-UserAttributesData -PipelineObject $user -LogFile $LogFile
        # 3. Look up user (and manager) in AD
        Get-UserAttributesIdentity -PipelineObject $user -LogFile $LogFile -Config $Config
        # 4. Plan only what's different
        New-UserAttributesPlan -PipelineObject $user -LogFile $LogFile
        # 5. Execute
        if ($Apply) {
            $null = Start-UserAttributesUpdate -PipelineObject $user -LogFile $LogFile -SnapshotFolder "$reportDir\Snapshots\UserAttributes_$runStamp"
        } else {
            Write-Log -Message "[$($user.CorrelationId)] [DRY RUN] Not updating: $($user.Raw.SamAccountName)" -Level "INFO" -LogFile $LogFile
        }
    }

    # 6. Report
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\UserAttributesReport_$runStamp.txt"
    $null = New-Report -Users $users -ReportFile $reportFile
    Write-Log -Message "Report generated: $reportFile" -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Total      = $users.Count
        Updated    = @($users | Where-Object Status -eq "Updated").Count
        Failed     = @($users | Where-Object Status -in @("Failed", "Invalid", "NotFound")).Count
        ReportFile = $reportFile
        Users      = @($users | ForEach-Object {
            [pscustomobject]@{
                SamAccountName = $_.Raw.SamAccountName
                Status         = $_.Status
                Changes        = ($_.Plan | ForEach-Object { "$($_.Target): '$($_.Old)' -> '$($_.Value)'" }) -join '; '
                Errors         = ($_.Errors | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.Message } }) -join '; '
            }
        })
    }
}
