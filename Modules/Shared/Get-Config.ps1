function Get-Config{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Onboarding", "Offboarding")]
        [string]$Script,

        [Parameter(Mandatory)]
        [string]$Client,

         [Parameter(Mandatory)]
        [string]$RootPath
    )

    $clientPath = "$RootPath\Config\Clients\$Client\$Script.json"

    if (-Not (Test-Path $clientPath)) {
        throw "Client config not found: $clientPath"
    }

    $clientConfig = Get-Content $clientPath -Raw | ConvertFrom-Json

    return $clientConfig
}