function Wait-ForEntraUser {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Check if user exists in Entra via Graph
    $user = Get-MgUser -UserId $Identity.EntraUPN -ErrorAction SilentlyContinue

    if ($null -eq $user) {
        Write-Log -Message "`tWaitForEntra           : User not yet in Entra, retrying..." -Level "WARN" -LogFile $LogFile
        throw "User not found in Entra yet"  # triggers retry
    }

    Write-Log -Message "`tWaitForEntra           : User found in Entra" -Level "INFO" -LogFile $LogFile
}