# Demo

One command runs a whole employee's story against the lab and puts everything it produced in one folder.

```powershell
# Preview - changes nothing
.\Demo\Invoke-Demo.ps1 -Client Lab

# Run it
.\Demo\Invoke-Demo.ps1 -Client Lab -Apply
```

**Lab only.** It deletes and recreates the demo account every run, so it can be run in front of someone twice without a reset.

---

## The story

| | Chapter | What it shows |
|---|---|---|
| 1 | **Hired** | Account created in the right department with the right access and a temporary password |
| 2 | **Promoted** | Old role access removed, new access added, moved department |
| 3 | **Name change** | Married: new name, new username, and **mail to the old address still arrives** |
| 4 | **Leaving** | Locked out, access stripped, moved to the leavers area |
| 5 | **Undo** | Put back exactly as the before-snapshot recorded them |

After every chapter it prints the account as it stands, read back out of Active Directory — not from the script's own output:

```
 3. NAME CHANGE
      Name     : Jordan Brooks   (jordanbrooks)
      Job      : Support Technician, IT
      Enabled  : True
      Where    : OU=IT,OU=Employees,OU=Users,OU=Identity
      Access   : GRP_ROLE_IT_Helpdesk, GRP-AllStaff

 4. LEAVING
      Name     : Jordan Brooks   (jordanbrooks)
      Enabled  : False
      Where    : OU=Disabled,OU=Users,OU=Identity
      Access   : none
```

---

## What you get

`Demo\Output\Demo_<date>\`

```
demo.txt                      everything printed, word for word
OnboardingReport_*.txt        one report per step
MoverReport_*.txt
NameChangeReport_*.txt
OffboardingReport_*.txt
RestoreReport_*.txt
Snapshots\
    jordanbrooks_before.json  the account before it was offboarded
    jordanbrooks_after.json   and after
```

Good for screenshots, and good for showing someone what a run actually leaves behind.

---

## Requirements

* The lab domain from [Lab](../Lab/README.md), with the OU structure from [AD Structure](../ADStructure/README.md)
* A client config with `"Environment": "OnPrem"` (or a full hybrid config, in which case the cloud steps run too)
* PowerShell 7 and the ActiveDirectory module, on the domain controller or a machine with RSAT
