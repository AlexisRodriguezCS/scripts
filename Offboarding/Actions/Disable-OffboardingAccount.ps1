function Disable-OffboardingAccount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    $dn = $Identity.DistinguishedName

    # Disable account
    Disable-ADAccount -Identity $dn -ErrorAction Stop

    # Reset password to a random value nobody knows
    $securePassword = ConvertTo-SecureString "$([guid]::NewGuid())!Aa1" -AsPlainText -Force
    Set-ADAccountPassword -Identity $dn -NewPassword $securePassword -Reset -ErrorAction Stop

    # Stamp the account so it's clear why it's disabled
    Set-ADUser -Identity $dn -Description "Offboarded $(Get-Date -Format 'yyyy-MM-dd')" -ErrorAction Stop

    return "Disabled"
}
