<#
.SYNOPSIS
    Update all users IDs
.DESCRIPTION
    Update all users IDs by reading in a csv and using a powershell loop
.NOTES
    Author: Alexis Rodriguez
    Date: 2026-01-30
#>

# Pass CSV as param
param(
    [string]$CSVPath = "C:\Data\employees_ids.csv"
)

# Check if CSV exists
if (-not (Test-Path $CSVPath)) {
    Write-Host "ERROR: CSV file not found at $CSVPath"
    exit
}

# Import Active Directory module
Import-Module ActiveDirectory

# Get data(employees) from CSV file
$employees = Import-Csv -Path $CSVPath

# Loop through employees
foreach($employee in $employees){
    # username = firstName +lastName
    $username = ($employee.FirstName + "." + $employee.LastName).ToLower()

    # Returns the AD user object if a matching user is found
    $adUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -Properties EmployeeID -ErrorAction SilentlyContinue

    # Check if user exists
    if($adUser){
        Write-Host "$($employee.FirstName + " " + $employee.LastName) ID before: $($adUser.EmployeeID)"

        Set-ADUser -Identity $adUser -EmployeeID $employee.EmployeeID

        # Call adUser to show change was made
        $adUser = Get-ADUser -Filter "SamAccountName -eq '$username'" -Properties EmployeeID -ErrorAction SilentlyContinue
        Write-Host "$($employee.FirstName + " " + $employee.LastName) ID after: $($adUser.EmployeeID)"
    } else {
        Write-Host "User $username not found in AD."
    }
}