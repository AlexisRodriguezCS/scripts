<#
.SYNOPSIS
    Create Users in Active Directory
.DESCRIPTION
    reate Users in Active Directory via CVS
.PARAMETER CSVPath
    Path to CSV file
.EXAMPLE
    .\Create-UsersFromCSV.ps1 -CSVPath "C:\Data\new_hires.csv"
.NOTES
    Author: Alexis Rodriguez
    Date: 2026-01-29
#>

# Pass CSV as param
param(
    [Parameter(Mandatory=$true)]
    [string]$CSVPath
)

# Check if CSV exists
if (-not (Test-Path $CSVPath)) {
    Write-Host "ERROR: CSV file not found at $CSVPath"
    exit 1
}

# Import Active Directory module
Import-Module ActiveDirectory

# Get data(employees) from CSV file
$employees = Import-Csv -Path $CSVPath

# Loop through employees
foreach($employee in $employees){
    # username = firstName +lastName
    $username = ($employee.FirstName + "." + $employee.LastName).ToLower()
    $email = "$username@domain.com"
    
    # Check if username exists
    if(Get-ADUser -Filter "SamAccountName -eq '$username'" -ErrorAction SilentlyContinue){
        Write-Host "$username is taken."
        continue
    } 
    $dept  = $employee.Department
    $ouPath = "OU=$dept,OU=Employees,OU=Users,OU=Identity,DC=dev,DC=local"

    # Check if OU exists
    if (-not (Get-ADOrganizationalUnit -Identity $ouPath -ErrorAction SilentlyContinue)) {
        Write-Host "OU NOT FOUND: $ouPath."
        continue
    }

    $first = $employee.FirstName
    $last  = $employee.LastName

    # Create new user
    New-ADUser `
    -Name "$first $last" `
    -SamAccountName $username `
    -UserPrincipalName $email `
    -Department $dept `
    -Title $employee.Title `
    -EmployeeID $employee.EmployeeID `
    -OfficePhone $employee.Phone `
    -Manager $employee.Manager `
    -Path $ouPath `
    -AccountPassword (ConvertTo-SecureString "TempPassword123!" -AsPlainText -Force) `
    -Enabled $true

    Write-Host "Created user: $username ($dept)"
}

