function Invoke-EntraSync {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Config,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    try {
        # Trigger delta sync on the AD Connect server
        Invoke-Command -ComputerName $Config.ADConnectServer -ScriptBlock {
            Import-Module ADSync
            Start-ADSyncSyncCycle -PolicyType Delta
        }
        Write-Log -Message "`tSyncToEntra            : Delta sync triggered" -Level "INFO" -LogFile $LogFile
    }
    catch {
        throw "Failed to trigger AD sync: $($_.Exception.Message)"
    }
}