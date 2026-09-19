function Get-Config{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Onboarding", "Offboarding", "Mover", "InactiveAccounts", "PasswordExpiry", "Audits", "Requests")]
        [string]$Script,

        [Parameter(Mandatory)]
        [string]$Client,

         [Parameter(Mandatory)]
        [string]$RootPath
    )

    # SCRIPTS_CONFIG_ROOT lets scheduled runs keep config outside the repo (checkout wipes ignored files)
    $configRoot = if ($env:SCRIPTS_CONFIG_ROOT) { $env:SCRIPTS_CONFIG_ROOT } else { "$RootPath\Config\Clients" }
    $clientPath = "$configRoot\$Client\$Script.json"

    if (-Not (Test-Path $clientPath)) {
        throw "Client config not found: $clientPath"
    }

    $clientConfig = Get-Content $clientPath -Raw | ConvertFrom-Json

    return $clientConfig
}
