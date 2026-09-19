#Requires -Version 7.0
#Requires -RunAsAdministrator
<#
    One-time setup on the server that runs the scripts: creates the certificate the scripts sign in with.

    .\Setup\New-AutomationCertificate.ps1 -RunAs "CONTOSO\svc-automation$" -OutFile .\automation.cer

    - The private key is created on this machine and marked NON-EXPORTABLE: it can't be copied off, even by an admin
    - Only the service account (and local admins) can read it
    - Only the PUBLIC key (.cer) leaves the machine; upload it to the Entra app registration
    - Put the printed thumbprint in the client configs (it's an ID, not a secret)
#>
[CmdletBinding()]
param(
    [string]$Subject = "CN=IdentityAutomation",

    # Account the scheduled tasks run as (a gMSA ends with $)
    [Parameter(Mandatory)]
    [string]$RunAs,

    # Short lifetime forces rotation; the AppCredentials audit warns 30 days before it expires
    [ValidateRange(1, 24)]
    [int]$Months = 12,

    [Parameter(Mandatory)]
    [string]$OutFile
)

$cert = New-SelfSignedCertificate -Subject $Subject `
                                  -CertStoreLocation "Cert:\LocalMachine\My" `
                                  -KeyExportPolicy NonExportable `
                                  -KeySpec Signature `
                                  -KeyAlgorithm RSA -KeyLength 3072 -HashAlgorithm SHA256 `
                                  -NotAfter (Get-Date).AddMonths($Months)

# Grant the service account read access to the private key file, nobody else
$rsa     = [System.Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
$keyFile = Join-Path "$env:ProgramData\Microsoft\Crypto\Keys" $rsa.Key.UniqueName
icacls $keyFile /grant "${RunAs}:R" | Out-Null

# Public key only
$null = Export-Certificate -Cert $cert -FilePath $OutFile

Write-Host "Certificate created (private key stays on this machine, not exportable)" -ForegroundColor Green
Write-Host "  Thumbprint : $($cert.Thumbprint)   <- put this in the client configs"
Write-Host "  Expires    : $($cert.NotAfter.ToString('yyyy-MM-dd'))"
Write-Host "  Public key : $OutFile   <- upload to Entra > App registrations > Certificates & secrets"
