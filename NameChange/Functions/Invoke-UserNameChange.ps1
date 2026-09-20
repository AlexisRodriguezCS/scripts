function Invoke-UserNameChange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Requests,

        [Parameter(Mandatory)]
        [string]$LogFile,

        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [bool]$Apply
    )

    $pipelineStart = Get-Date
    $runStamp      = Get-Date -Format 'yyyyMMdd_HHmmss'
    $reportDir     = "$PSScriptRoot\..\..\Reports"

    # 1. Build requests
    $users = @($Requests | ForEach-Object { New-NameChangeRequest -Row $_ -LogFile $LogFile })

    $processed = @()

    foreach ($user in $users) {
        # 2. Validate
        Test-NameChangeData -PipelineObject $user -LogFile $LogFile
        # 3. Look up the user and work out the new name
        Get-NameChangeIdentity -PipelineObject $user -LogFile $LogFile -Config $Config
        # 4. Plan only what's different
        New-NameChangePlan -PipelineObject $user -LogFile $LogFile -Config $Config
        # 5. Execute
        if ($Apply) {
            $null = Start-NameChange -PipelineObject $user -LogFile $LogFile -Config $Config -SnapshotFolder "$reportDir\Snapshots\NameChange_$runStamp"
        } else {
            Write-Log -Message "[$($user.CorrelationId)] [DRY RUN] Not renaming: $($user.Raw.SamAccountName)" -Level "INFO" -LogFile $LogFile
        }

        # Stop the run if the same failure keeps repeating (AD down, expired certificate, lost permission)
        $processed += $user
        if (Test-CircuitBreaker -Processed $processed -Config $Config -LogFile $LogFile) {
            foreach ($rest in $users | Where-Object Status -eq "Pending") { $rest.Status = "Stopped" }
            break
        }
    }

    # 6. Report
    $null = New-Item -ItemType Directory -Path $reportDir -Force
    $reportFile = "$reportDir\NameChangeReport_$runStamp.txt"
    $null = New-Report -Users $users -ReportFile $reportFile

    Write-Log -Message "=== Pipeline Finished === Total: $($users.Count) | Renamed: $(@($users | Where-Object Status -eq 'Renamed').Count) | Duration: $(((Get-Date) - $pipelineStart).TotalSeconds) sec" `
              -Level "INFO" -LogFile $LogFile

    return [pscustomobject]@{
        Total      = $users.Count
        Renamed    = @($users | Where-Object Status -eq "Renamed").Count
        NoChange   = @($users | Where-Object Status -eq "NoChange").Count
        Failed     = @($users | Where-Object Status -in @("Failed", "Invalid", "NotFound", "Stopped")).Count
        ReportFile = $reportFile
        Users      = @($users | ForEach-Object {
            [pscustomobject]@{
                SamAccountName = $_.Raw.SamAccountName
                NewName        = $_.Identity.DisplayName
                NewUsername    = $_.Identity.NewSamAccountName
                Status         = $_.Status
                Errors         = ($_.Errors | ForEach-Object { if ($_ -is [string]) { $_ } else { $_.Message } }) -join '; '
            }
        })
    }
}
