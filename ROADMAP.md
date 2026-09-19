# Roadmap

What a business actually needs from identity automation: **stay secure, stop wasting money, pass audits, save help desk time.**

---

## Done

**Employee lifecycle (Joiner – Mover – Leaver)**
- [x] **Onboarding** – new hire gets account, groups, email lists, license, random temp password
- [x] **Role change (mover)** – new title/department/manager, old role access swapped for new
- [x] **User attributes** – HR/IT update details (title, phone, office...), only what changed
- [x] **Offboarding** – lock out, remove access, mailbox + OneDrive to manager, free licenses
- [x] **One person or bulk** – every people script takes parameters or a CSV

**Security**
- [x] **Inactive accounts** – disable unused employees, remove old guests, safety stop
- [x] **MFA gaps** – no MFA, admins on SMS only
- [x] **Admin audit** – role holders, too many Global Admins, guests with admin
- [x] **Mail forwarding audit** – forwarding and inbox rules to outside addresses
- [x] **Expiring app secrets / certificates**

**Save money**
- [x] **License report** – bought vs assigned, cost per department
- [x] **Wasted licenses** – unused, on disabled accounts, on idle accounts

**Audits and compliance**
- [x] **Access review** – one sheet per manager, Keep/Remove
- [x] **Offboarding check** – leavers still enabled, in groups, or licensed
- [x] **Before/after snapshots** – every change recorded as JSON

**Help desk**
- [x] **Password expiry emails** – 14/7/1 days, never duplicated

**Platform**
- [x] **HR self-service** – SharePoint list + approval, results written back in plain English
- [x] **Scheduled / emergency** – requests run at a set time (a leaver's last day at 5 PM) or ASAP
- [x] **Alerts** – Teams and/or email when anything needs attention
- [x] **Scheduled tasks** – one setup script, runs as a gMSA (no stored password)

---

## Next up

- [ ] **Home lab** – domain controller + Entra Connect on Proxmox/Hyper-V, run everything for real, add screenshots to the READMEs
- [ ] **Temporary Access Pass** – new hires get a one-time sign-in code instead of a temp password (passwordless onboarding)
- [ ] **Undo from snapshot** – restore a user's groups/attributes from a before-snapshot
- [ ] **Offboarding: hide from address book, remove from Teams/SharePoint sites, wipe company data from phones (Intune)**

---

## Last: demo portal

A small web page, hosted on the lab PC, that shows what the scripts do in real time:

- Pick a request (new hire, role change, leaver, update info) and watch each step run with a progress animation
- Each change shown as it happens, e.g. **Lisa Taylor – Title: Accountant → Finance Manager ✓**
- Offboarding shows the user's **before** and **after** side by side (from the snapshots): enabled → disabled, 5 groups → 0, E3 license → none, mailbox → shared
- Reads the same reports and snapshots the scripts already write, so it doesn't change how anything works

Good for demos and interviews. The real HR front door stays the SharePoint list (sign-in, permissions and approvals come free with Microsoft 365).
