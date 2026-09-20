# Stale Devices (Intune)

Cleans up laptops and phones that stopped checking in to Intune.
Lost, replaced or forgotten devices still hold company data and clutter compliance reports.

Pipeline details: [Docs/StaleDevices.md](Docs/StaleDevices.md)

---

## Steps

1. Get every Intune device and its last check-in
2. Skip devices on the exclusion list (kiosks, spares)
3. Mark as stale: no check-in for `RetireAfterDays` (default 90)
4. Plan per stale device:
   * **Retire**: removes company data, apps and email on its next check-in (personal data untouched). Not sent twice.
   * **Delete record**: no check-in for `DeleteAfterDays` (default 180); the device is gone, remove it from Intune
5. **Safety stop:** if more than `MaxPercentToChange` (default 20%) of devices would change, nothing runs
6. Run the plan with retries
7. Write a report + CSV (device, owner, serial, last check-in) to `Reports/`
8. Alert if there's anything to review or anything failed

Steps 6 only runs with `-Apply`.

---

## Usage

Review only:
```powershell
.\StaleDevices\StaleDevices.ps1 -Client "ClientA"
```
Make the changes:
```powershell
.\StaleDevices\StaleDevices.ps1 -Client "ClientA" -Apply
```

---

## Config (`StaleDevices.json`)

```json
{
    "RetireAfterDays": 90,
    "DeleteAfterDays": 180,
    "MaxPercentToChange": 20,
    "ExcludeDevices": ["LOBBY-KIOSK", "CONF-ROOM-1"],
    "TenantId": "00000000-0000-0000-0000-000000000000",
    "ClientId": "11111111-1111-1111-1111-111111111111",
    "CertThumbprint": "0000000000000000000000000000000000000000"
}
```

Graph permissions: `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`.
