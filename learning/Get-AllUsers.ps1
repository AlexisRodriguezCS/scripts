<#
.SYNOPSIS
    Get all Active Directory users
.DESCRIPTION
    Get all Active Directory users
.NOTES
    Author: Alexis Rodriguez
    Date: 2026-01-27
#>

# Loads the Active Directory PowerShell module.
Import-Module ActiveDirectory

# Gets all users with fields of Department, Title, Enabled.
$users = Get-ADUser -Filter * -Properties Department, Title, Enabled

# For loop to print every user's name, department, title, and if they are enabled.
foreach ($user in $users) {
    $department = if ($user.Department) { $user.Department } else { "N/A" }
    $title = if ($user.Title) { $user.Title } else { "No Title" }
    $status = if ($user.Enabled) { "Enabled" } else { "Disabled"}
    Write-Host "$status $($user.name) - $department - $title"
}

# Using pipeline to display data in gridview popup
Get-ADUser -Filter * -Properties Department, Title, Enabled |
    Where Enabled -eq $true |
    Select Name, Department, Title |
    Out-GridView

# Using pipeline to display data in gridview popup
Get-ADUser -Filter * -Properties Department, Title, Enabled |
    Sort Department |
    Select Name, Enabled, Department, Title |
    Out-GridView
