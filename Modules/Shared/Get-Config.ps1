function Get-Config{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet("Onboarding", "Offboarding")]
        [string]$Script
    )

    $sharedPath = "$PSScriptRoot\..\..\Config\Shared.json"
    $scriptPath = "$PSScriptRoot\..\..\Config\$Script.json"

    # Validate that the shared and script config files exist
    if(-Not(Test-Path $sharedPath)){
        throw "Shared config not found: $sharedPath"
    }

    if(-Not(Test-Path $scriptPath)){
        throw "Script config not found: $scriptPath"
    }
    
    # Load both configs and convert from JSON
    $shared = Get-Content $sharedPath -Raw | ConvertFrom-Json
    $scriptConfig   = Get-Content $scriptPath -Raw | ConvertFrom-Json

    # Merge into one object
    $merged = @{}
    $shared.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value }
    $scriptConfig.PSObject.Properties | ForEach-Object { $merged[$_.Name] = $_.Value }

    return [PSCustomObject]$merged
}