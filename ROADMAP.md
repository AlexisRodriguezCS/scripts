# Roadmap

What a business actually needs from identity automation: **stay secure, stop wasting money, pass audits, save help desk time.**

---

## Done

- [x] **Onboarding** – new hire gets account, groups, email lists, license
- [x] **Offboarding** – leaver locked out, access removed, data handed to manager, licenses freed

---

## Next up

### 1. Complete the employee lifecycle
- [ ] **Role change (mover)** – when someone changes department or role, swap their groups, email lists and OU. Onboarding + offboarding + mover = the full *Joiner-Mover-Leaver* process every IT team runs.
  - *Why:* people who change jobs keep their old access forever ("permission creep"). Auditors flag this constantly.

### 2. Security
- [ ] **Stale accounts** – find accounts with no sign-in for 90+ days, disable them, report.
  - *Why:* unused accounts are an easy way in for attackers, and nobody notices them.
- [ ] **MFA gaps** – list users with no MFA, and admins without strong MFA.
  - *Why:* no MFA is the #1 way accounts get taken over. Cyber insurance asks about it.
- [ ] **Admin audit** – who has Global Admin and other powerful roles, and are they permanent.
  - *Why:* too many admins = big damage if one is hacked.
- [ ] **Mail forwarding audit** – find mailboxes auto-forwarding to outside addresses.
  - *Why:* the first thing attackers set up after a break-in, to quietly copy email out.
- [ ] **Guest user cleanup** – external guests who haven't signed in for 90 days.
  - *Why:* old vendors and contractors still having access to company files.
- [ ] **Expiring app secrets / certificates** – warn 30 days before app registrations expire.
  - *Why:* an expired secret silently breaks integrations (including these scripts).

### 3. Save money
- [ ] **License report** – who has what license, what it costs, per department.
  - *Why:* finance wants to know what M365 costs per team.
- [ ] **Wasted licenses** – licenses on disabled or inactive users, and unassigned ones still being paid for.
  - *Why:* often 10–20% of licenses are wasted. Easy savings to show a manager.

### 4. Audits and compliance
- [ ] **Access review export** – each manager gets a list of what their team has access to, to approve or remove.
  - *Why:* required for SOC 2, ISO 27001, HIPAA and most audits, usually every quarter.
- [ ] **Offboarding check** – confirm every leaver from HR is actually disabled with no licenses.
  - *Why:* proves to auditors that offboarding really happened.

### 5. Help desk time savers
- [ ] **Password expiry emails** – remind users 14/7/1 days before their password expires.
  - *Why:* cuts "I'm locked out" tickets.

---

## Platform

- [ ] **Alerts** – email or Teams message when anything lands in NEEDS ATTENTION
- [ ] **Scheduled runs** – run on a schedule from an HR export (self-hosted GitHub runner or Task Scheduler)
- [ ] **Home lab** – domain controller + Entra Connect on Proxmox/Hyper-V to test everything for real
