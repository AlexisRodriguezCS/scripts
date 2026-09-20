# AD Structure

Builds a client's Active Directory layout from a JSON file: OUs, groups, and where new users and computers land by default.

---

## Why this exists

A brand-new domain gives you almost nothing:

| What you get | Type |
|---|---|
| `Domain Controllers` | OU |
| `Users` | **Container** |
| `Computers` | **Container** |
| `Builtin`, `System`, `ForeignSecurityPrincipals`... | Containers |

**Group Policy can't be linked to a container.** So the two places Windows puts things by default — new accounts in `CN=Users`, new domain-joined PCs in `CN=Computers` — are exactly the places your policies can't reach. Every machine that joins the domain sits outside the baseline until someone moves it.

This script builds a real OU tree and then points the defaults at it.

---

## Steps

1. Read the structure file (client's own, or the sample in `Data/`)
2. Create the OU tree, parents before children, skipping anything that exists
3. Create the groups, in the OUs the file names
4. Point new **users** and new **computers** at real OUs (`redirusr` / `redircmp`)
5. Write a summary and a log

Dry run by default: it prints what it *would* create. Add `-Apply` to build it. Safe to re-run — existing objects are left alone.

---

## Usage

```powershell
# Preview
.\ADStructure\New-ADStructure.ps1 -Client "ClientA"

# Build it
.\ADStructure\New-ADStructure.ps1 -Client "ClientA" -Apply

# Build the OUs but leave the default landing spots alone
.\ADStructure\New-ADStructure.ps1 -Client "ClientA" -Apply -SkipRedirect
```

The structure file is `Config\Clients\<Client>\structure.json` if it exists, otherwise [`Data\structure.json`](Data/structure.json). Override with `-Path`.

---

## The default layout

```
OU=Identity
├── OU=Users
│   ├── OU=Employees        ← new accounts land here (one OU per department)
│   ├── OU=Contractors
│   ├── OU=ServiceAccounts
│   └── OU=Disabled         ← leavers get moved here by offboarding
├── OU=Computers
│   ├── OU=Workstations     ← new domain-joined PCs land here
│   ├── OU=Laptops
│   ├── OU=Kiosks
│   └── OU=Disabled         ← retired hardware
├── OU=Servers
│   ├── OU=Application
│   ├── OU=Database
│   └── OU=Infrastructure
└── OU=Groups
    ├── OU=Role             ← GRP_ROLE_* (the only groups the scripts manage)
    ├── OU=Security
    └── OU=Distribution
```

Change it by editing the JSON — the tree is read as written, to any depth.

```json
{
    "ProtectFromDeletion": true,
    "OUs": [
        { "Name": "Identity", "Children": [
            { "Name": "Users", "Children": [ { "Name": "Employees" } ] }
        ]}
    ],
    "Groups": [
        { "Name": "GRP-AllStaff", "Path": "OU=Security,OU=Groups,OU=Identity" }
    ],
    "Redirect": {
        "Users": "OU=Employees,OU=Users,OU=Identity",
        "Computers": "OU=Workstations,OU=Computers,OU=Identity"
    }
}
```

`Path` on a group and the `Redirect` values are relative — the domain (`DC=contoso,DC=local`) is added for you, so the same file works for any client.

---

## Notes

* **`ProtectFromDeletion`** sets accidental-deletion protection on every OU. It's what stops someone dragging a department into oblivion in ADUC. Turn it off for a lab you rebuild often.
* **`redirusr` / `redircmp`** ship with AD DS and have no PowerShell equivalent, so the script calls them directly. They change the domain's own `wellKnownObjects`, visible afterwards as `(Get-ADDomain).UsersContainer`.
* The OU names here line up with the other scripts: onboarding puts a new hire in `OU=<Department>,<DefaultOU>`, offboarding moves leavers to `DisabledOU`, and only `GRP_ROLE_*` groups are touched on a role change.
