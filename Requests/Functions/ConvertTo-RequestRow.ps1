function ConvertTo-RequestRow {
    [CmdletBinding()]
    param(
        # SharePoint list item fields (internal column names)
        [Parameter(Mandatory)]
        [hashtable]$Fields
    )

    function Get-Field([string]$name) { "$($Fields[$name])".Trim() }

    # Turn a form submission into the row shape each script already understands
    switch (Get-Field "RequestType") {
        "New hire" {
            [pscustomobject]@{
                FirstName = Get-Field "FirstName"; LastName = Get-Field "LastName"; Title = Get-Field "JobTitle"
                Manager = Get-Field "ManagerName"; Location = Get-Field "Office"; Department = Get-Field "Department"
                Role = Get-Field "Role"; EmploymentType = Get-Field "EmploymentType"; StartDate = Get-Field "StartDate"
                EmployeeID = Get-Field "EmployeeID"
            }
        }
        "Role change" {
            [pscustomobject]@{
                SamAccountName = Get-Field "Username"; Title = Get-Field "JobTitle"; Department = Get-Field "Department"
                Role = Get-Field "Role"; Manager = Get-Field "ManagerUsername"; EmploymentType = Get-Field "EmploymentType"
            }
        }
        "Leaver" {
            [pscustomobject]@{ SamAccountName = Get-Field "Username"; Manager = Get-Field "ManagerEmail" }
        }
        "Update info" {
            # Only the boxes HR filled in; blanks are ignored by the attributes script
            [pscustomobject]@{
                SamAccountName = Get-Field "Username"; Title = Get-Field "JobTitle"; Department = Get-Field "Department"
                Manager = Get-Field "ManagerUsername"; Office = Get-Field "Office"
                OfficePhone = Get-Field "OfficePhone"; MobilePhone = Get-Field "MobilePhone"
            }
        }
        default { throw "Unknown request type '$(Get-Field "RequestType")'" }
    }
}
