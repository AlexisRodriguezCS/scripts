function Invoke-EntraSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    Write-Log -Message "[GLOBAL] [Invoke-EntraSync] Starting delta sync" `
        -Level "INFO" -LogFile $LogFile

    try {
        # Trigger delta sync on the AD Connect server
        Invoke-Command -ComputerName $Config.ADConnectServer -ScriptBlock {
            Import-Module ADSync
            Start-ADSyncSyncCycle -PolicyType Delta
        }
        Write-Log -Message "[GLOBAL] [Invoke-EntraSync] Delta sync triggered successfully" `
            -Level "INFO" -LogFile $LogFile
    }
    catch {
        Write-Log -Message "[GLOBAL] [Invoke-EntraSync] Failed: $($_.Exception.Message)" `
            -Level "ERROR" -LogFile $LogFile
        throw
    }
}