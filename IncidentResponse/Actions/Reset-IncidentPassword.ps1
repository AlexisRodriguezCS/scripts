function Reset-IncidentPassword {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingConvertToSecureStringWithPlainText', '', Justification = 'Random throwaway password, never stored or shown')]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # A long random password nobody knows; the real user gets a new one from IT once it's safe
    $password = New-RandomPassword -Length 32

    if ($Identity.Synced) {
        Set-ADAccountPassword -Identity $Identity.SamAccountName -NewPassword (ConvertTo-SecureString $password -AsPlainText -Force) -Reset -ErrorAction Stop
        return "Reset in AD"
    }

    Update-MgUser -UserId $Identity.Id -PasswordProfile @{ Password = $password; ForceChangePasswordNextSignIn = $true } -ErrorAction Stop
    return "Reset in Entra"
}
