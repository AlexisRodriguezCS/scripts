# AD attributes these scripts are allowed to change (same names on Get-ADUser and Set-ADUser)
$script:ManagedUserAttributes = @(
    "Title", "Department", "Manager", "Office", "OfficePhone", "MobilePhone",
    "Company", "EmployeeID", "City", "State", "StreetAddress", "PostalCode", "Description"
)

function Set-UserAttribute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Identity,

        [Parameter(Mandatory)]
        [ValidateScript({ $_ -in $script:ManagedUserAttributes })]
        [string]$Attribute,

        [Parameter(Mandatory)]
        [string]$Value,

        [Parameter(Mandatory)]
        [string]$LogFile
    )

    # Set-ADUser takes each attribute as its own parameter
    $params = @{ Identity = $Identity.DistinguishedName; ErrorAction = "Stop" }
    $params[$Attribute] = $Value

    Set-ADUser @params
    return "Updated"
}
