#Requires -Version 7.0
<#
    Store a secret (e.g. a Teams webhook URL) in the vault the scripts read from.
    Run it AS the service account (or in its context), since the local SecretStore is per user.

    .\Setup\Set-AutomationSecret.ps1 -Name "ClientA-TeamsWebhook"
    Then in config:  "AlertWebhookUrl": "secret:ClientA-TeamsWebhook"

    Production: register an Azure Key Vault instead of SecretStore (same scripts, same names):
      Register-SecretVault -Name AutomationVault -ModuleName Az.KeyVault -VaultParameters @{ AZKVaultName = "contoso-kv"; SubscriptionId = "..." }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Name,

    [string]$Vault = "AutomationVault"
)

foreach ($module in "Microsoft.PowerShell.SecretManagement", "Microsoft.PowerShell.SecretStore") {
    if (-not (Get-Module -ListAvailable -Name $module)) {
        throw "Missing module: $module (Install-Module $module -Scope CurrentUser)"
    }
}

# Lab: local encrypted store, no password prompt so scheduled tasks can read it.
# The store is encrypted and tied to this Windows user profile.
if (-not (Get-SecretVault -Name $Vault -ErrorAction SilentlyContinue)) {
    Register-SecretVault -Name $Vault -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault
    Set-SecretStoreConfiguration -Scope CurrentUser -Authentication None -Interaction None -Confirm:$false
}

# Typed in, never on the command line (command lines end up in shell history and process logs)
$value = Read-Host -Prompt "Value for '$Name'" -AsSecureString
Set-Secret -Name $Name -Vault $Vault -SecureStringSecret $value

Write-Host "Saved '$Name' in $Vault. Reference it in config as: `"secret:$Name`"" -ForegroundColor Green
