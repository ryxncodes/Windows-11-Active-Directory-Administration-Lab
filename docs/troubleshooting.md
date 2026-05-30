# Troubleshooting Runbook

This runbook covers common issues encountered or expected in the `rk-lab.local` Active Directory lab.

Use it as a first-pass checklist before rebuilding a VM or changing multiple settings at once.

## DNS Misconfiguration

### Symptoms

- Client cannot join the domain.
- Client can ping `DC01` by IP but not by hostname.
- `rk-lab.local` cannot be resolved from a workstation.
- Group Policy processing is unreliable or slow.

### Likely Causes

- Client DNS is pointed to a public resolver such as `8.8.8.8` or `1.1.1.1`.
- Client DNS is pointed to the host Mac or VirtualBox NAT instead of `DC01`.
- `DC01` does not have the correct static IP address.
- The AD DNS forward lookup zone is missing or unhealthy.

### Checks

Run these from the affected Windows client:

```powershell
ipconfig /all
nslookup dc01.rk-lab.local
ping DC01
nltest /dsgetdc:rk-lab.local
```

On `DC01`, verify:

- Static IP is `10.10.10.10`.
- DNS server is `10.10.10.10`.
- DNS Manager contains the `rk-lab.local` forward lookup zone.
- Clients use `10.10.10.10` as their DNS server.

### Fix

Set the Windows client DNS server to `10.10.10.10`, then retry name resolution and domain controller discovery.

```powershell
ipconfig /flushdns
ipconfig /registerdns
nltest /dsgetdc:rk-lab.local
```

## Failed Domain Joins

### Symptoms

- Domain join fails with a domain controller not found message.
- Domain join accepts credentials but does not complete.
- Workstation joins the domain but later has trust relationship errors.

### Likely Causes

- DNS is not pointed to `DC01`.
- Client is not attached to the `ADLab` VirtualBox Internal Network.
- Time is out of sync between client and domain controller.
- Computer account already exists in AD in a bad state.
- Domain controller hostname was changed after AD DS promotion.

### Checks

On the client:

```powershell
ipconfig /all
ping 10.10.10.10
ping DC01
nltest /dsgetdc:rk-lab.local
w32tm /query /status
```

In VirtualBox:

- Confirm the client adapter is attached to `Internal Network`.
- Confirm the internal network name is `ADLab`.

In Active Directory Users and Computers:

- Check whether the workstation computer object already exists.
- Confirm it is eventually moved to `RK-LAB/Computers/Workstations`.

### Fix

Fix DNS and network attachment first. If a stale computer object exists, remove it from ADUC, reboot the client, and retry the domain join.

If the domain controller was renamed after promotion and authentication is broken, rebuild from a clean baseline and set the hostname before promoting AD DS.

## Missing SYSVOL or NETLOGON

### Symptoms

- Browsing to `\\DC01` does not show `SYSVOL` or `NETLOGON`.
- Group Policy does not apply.
- Logon scripts or domain policy files are unavailable.
- Domain controller promotion appears incomplete.

### Likely Causes

- AD DS promotion did not complete successfully.
- DFS Replication for SYSVOL is not healthy.
- DNS or domain controller discovery is broken.
- The server is not functioning correctly as a domain controller.

### Checks

On `DC01`:

```powershell
net share
dcdiag /test:sysvolcheck
dcdiag /test:advertising
dcdiag /test:dns
```

Also check:

- `C:\Windows\SYSVOL\sysvol` exists.
- DNS contains the expected AD records for `rk-lab.local`.
- Event Viewer has no critical Directory Service or DFS Replication errors.

### Fix

If this is a new lab build, verify AD DS promotion completed and reboot `DC01`. If `SYSVOL` and `NETLOGON` remain missing, review `dcdiag` output and Event Viewer before joining clients or creating GPOs.

For this small lab, a failed or unhealthy first domain controller promotion may be faster to rebuild cleanly than to repair deeply.

## GPO Not Applying Due To Security Filtering

### Symptoms

- A GPO is linked to the correct OU but does not apply.
- `gpresult` does not show the expected user or computer GPO.
- Standard users are not receiving restrictions.
- Policy applies before security filtering but stops after filtering is changed.

### Likely Causes

- The target user or computer is not in the security-filtered group.
- The GPO lacks `Read` permission for policy processing.
- `Authenticated Users` was removed without adding separate delegation read access.
- The GPO is linked to the wrong OU.
- User settings are linked to a computer OU, or computer settings are linked to a user OU.

### Checks

On the client:

```powershell
gpupdate /force
gpresult /r
gpresult /scope computer /r
gpresult /scope user /r
```

In Group Policy Management:

- Confirm the GPO is linked to the correct OU.
- Confirm the GPO has the correct user or computer configuration enabled.
- Confirm the target account is in the security filtering group.
- Confirm `Authenticated Users` or another appropriate principal has `Read` permission under Delegation.
- Confirm only the intended group has `Apply group policy`.

### Fix

Keep security filtering limited to the intended group, but make sure the GPO can still be read during processing.

For example:

| Principal | Read | Apply Group Policy |
|---|---|---|
| `GG_Standard_Users` | Allow | Allow |
| `Authenticated Users` | Allow | Not Applied |

Then run:

```powershell
gpupdate /force
gpresult /scope user /r
```

## Drive Maps Not Appearing

### Symptoms

- Expected `P:`, `H:`, `F:`, or `O:` drive does not appear after logon.
- Public drive appears, but department drive does not.
- Department drive appears for the wrong user.
- Drive appears only after running `gpupdate /force` or logging out and back in.

### Likely Causes

- User is not in the correct department security group.
- Drive map item-level targeting is wrong.
- User GPO is linked to the wrong OU.
- The user logged in before group membership was refreshed.
- The share path is unavailable or permissions are blocking access.

### Checks

On the client:

```powershell
whoami
whoami /groups
gpupdate /force
gpresult /scope user /r
net use
```

In Group Policy Management:

- Confirm `GPO-Users-Mapped-Drives` is linked to `RK-LAB/Users`.
- Confirm item-level targeting points to the correct group.
- Confirm the drive map path is correct, such as `\\DC01\Departments\HR`.
- Confirm `Run in logged-on user's security context` is enabled where appropriate.

In ADUC:

- Confirm the user belongs to the correct group, such as `GG_HR_FileShare_RW`.

### Fix

Correct group membership or item-level targeting, then have the user sign out and sign back in. If testing immediately after a group change, refresh policy and use a fresh logon session.

```powershell
gpupdate /force
logoff
```

## NTFS and Share Permission Mismatches

### Symptoms

- User can see a share but cannot open the folder.
- User can open a share but cannot create or modify files.
- Permissions look correct on the Sharing tab but access is still denied.
- A department user can access another department folder unexpectedly.

### Likely Causes

- Share permissions and NTFS permissions do not align.
- Permissions were assigned directly to users instead of groups.
- User is in the wrong security group.
- Parent folder inheritance is granting unexpected access.
- Access-based expectations are being tested against the parent `Departments` share instead of a department folder.

### Checks

On `DC01`:

```powershell
Get-SmbShare
Get-SmbShareAccess -Name Departments
Get-SmbShareAccess -Name Public
icacls C:\Shares\Departments
icacls C:\Shares\Departments\HR
icacls C:\Shares\Departments\Finance
icacls C:\Shares\Departments\Operations
icacls C:\Shares\Public
```

On the client:

```powershell
whoami /groups
net use
```

Verify the intended access model:

| Resource | Expected Access |
|---|---|
| `\\DC01\Departments\HR` | HR group Modify, IT admins Full Control |
| `\\DC01\Departments\Finance` | Finance group Modify, IT admins Full Control |
| `\\DC01\Departments\Operations` | Operations group Modify, IT admins Full Control |
| `\\DC01\Public` | All employees Modify, IT admins Full Control |

### Fix

Use broad share permissions and precise NTFS permissions. Assign permissions to AD security groups instead of individual users.

Recommended pattern for this lab:

- Share permissions allow access broadly enough for users to reach the share.
- NTFS permissions enforce department-level access.
- Department folders grant Modify only to the matching department group.
- IT admin group has Full Control for administration.
- Public folder grants Modify to `GG_All_Employees`.

After permission changes, have the user close existing sessions and reconnect:

```powershell
net use * /delete
```

Then browse to the share again and retest allowed and denied access.
