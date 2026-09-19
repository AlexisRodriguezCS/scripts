function Get-Config{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
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

    # Secrets are never stored in config files. A value like "secret:ClientA-TeamsWebhook" is a
    # reference; the real value is fetched from the vault (SecretManagement) at run time.
    foreach ($property in $clientConfig.PSObject.Properties) {
        if ($property.Value -isnot [string] -or $property.Value -notlike "secret:*") { continue }

        $secretName = $property.Value.Substring("secret:".Length)

        if (-not (Get-Command Get-Secret -ErrorAction SilentlyContinue)) {
            throw "$Script config needs secret '$secretName' but Microsoft.PowerShell.SecretManagement is not installed"
        }

        $vault = if ($clientConfig.SecretVault) { @{ Vault = $clientConfig.SecretVault } } else { @{} }
        try {
            $value = Get-Secret -Name $secretName @vault -AsPlainText -ErrorAction Stop
        }
        catch {
            # Name only, never the value
            throw "Could not read secret '$secretName' for $($property.Name): $($_.Exception.Message)"
        }

        $property.Value = $value

        # Write-Log masks every secret value it has seen, so a secret can't end up in a log file
        if (-not $script:SecretValues) { $script:SecretValues = [System.Collections.Generic.List[string]]::new() }
        if ($value) { $script:SecretValues.Add($value) }
    }

    return $clientConfig
}
