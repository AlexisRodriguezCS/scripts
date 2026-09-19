# HR Requests (Self-Service)

HR doesn't run scripts. They fill in a SharePoint list, and the scripts do the rest.

---

## For HR: how to use it

1. Open the **IT Requests** list in SharePoint (or the Microsoft Lists / Teams app)
2. Click **+ New**
3. Pick the **Request type** and fill in the boxes:

| Request type | Fill in |
|---|---|
| **New hire** | First name, Last name, Employee ID, Job title, Department, Role, Manager name, Start date |
| **Role change** | Username, Job title, Department, Role, Manager username |
| **Leaver** | Username, Manager email (gets their mailbox + OneDrive) |
| **Update info** | Username + only the boxes that change (phone, title, office...) |
| **Unlock account** | Username |
| **Reset password** | Username (IT gets the temporary password and hands it over; it's never shown in the list) |
| **Group access** | Username, Group, Add or remove (only groups IT has allowed for requests) |

4. **When**: leave blank for as soon as possible, or pick a date and time (e.g. a leaver's last day at 5 PM)
5. Save. The request waits for approval.

The **Status** column tells you what's happening:

| Status | Meaning |
|---|---|
| New | Waiting for approval |
| Approved | Approved, will run at the "When" time (or within 15 minutes) |
| Processing | Running now |
| Done | Finished; **Result** says what was done |
| Needs attention | Something's wrong; **Result** says what (e.g. "no account found with username jsmyth"). IT is alerted too |
| Rejected | Not approved |

**Emergency leaver?** Leave "When" blank. Or call IT: they can run it instantly.

---

## For IT: setup

1. Create the list (one time):
   ```powershell
   .\Requests\Setup\New-RequestList.ps1 -SiteUrl "https://contoso.sharepoint.com/sites/HR" -Departments Finance,IT,Sales,HR,Marketing
   ```
2. Permissions: HR = Contribute, approvers = Edit.
3. Approval: either an approver changes **Status** to *Approved*, or add a Power Automate flow
   (*When an item is created* → *Start and wait for an approval* → set Status to Approved / Rejected).
4. Add `Config/Clients/<Client>/Requests.json` (see main README).
5. Schedule the queue every 15 minutes:
   ```powershell
   .\Requests\Invoke-RequestQueue.ps1 -Client "ClientA" -Apply
   ```

---

## Steps (each run)

1. Read the list, keep **Approved** items (and ones stuck on **Processing** for over an hour, from a crashed run)
2. **Check the approval is real**: SharePoint's version history must show the change to Approved was made by someone on `Approvers`, and not by the person who submitted it. Otherwise: *Needs attention*
3. Skip items whose **When** is in the future (shows "Scheduled: will run ...")
4. Set **Processing** (so two runs can't do the same request)
5. Run the matching script: onboarding, mover, offboarding, user attributes, or the help desk actions (unlock, reset password, group access)
6. Temp passwords are emailed to IT, **never** written to the list
7. Set **Done** or **Needs attention** with a plain-English result
8. Alert IT if anything needs attention
