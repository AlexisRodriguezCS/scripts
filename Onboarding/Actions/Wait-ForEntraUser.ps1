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
        throw "User not found in Entra yet"  # triggers retry
    }
    
    return "Found"
}