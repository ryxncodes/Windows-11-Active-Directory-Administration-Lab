# Phase 6 - Group Policy

## Objective

Configure and test realistic Group Policy Objects for the `rk-lab.local` domain.

This phase demonstrates how Group Policy can be used to manage workstation behavior, standard user restrictions, mapped drives, local administrator membership, login notices, Windows Update behavior, and domain account policy.

## GPO Summary

| GPO Name | Linked Location | Configuration Type | Purpose | Expected Result | Actual Result |
|---|---|---|---|---|---|
| `GPO-Workstations-Login-Banner` | `RK-LAB/Computers/Workstations` | Computer | Display authorized use notice before sign-in | Login banner appears before user logon | Pass |
| `GPO-Workstations-Local-Admins` | `RK-LAB/Computers/Workstations` | Computer Preference | Add IT admin group to local Administrators group on workstations | `RK-LAB\GG_IT_Admins` becomes local admin on workstations | Pass |
| `GPO-Workstations-Windows-Update` | `RK-LAB/Computers/Workstations` | Computer | Configure managed Windows Update behavior for workstations | Windows Update GPO appears in computer-side `gpresult` output | Pass |
| `GPO-Users-Mapped-Drives` | `RK-LAB/Users` | User Preference | Map Public and department drives based on user group membership | Users receive Public drive plus their department drive | Pass |
| `GPO-Users-Standard-Restrictions` | `RK-LAB/Users` | User | Restrict standard users from Control Panel and PC Settings | Standard users are blocked; IT users are not blocked | Pass |
| `Default Domain Policy` | `rk-lab.local` domain root | Account Policy | Configure password and account lockout policy | Users are subject to password complexity and lockout rules | Pass |

## GPO 1 - Login Banner

### Purpose

Display an authorized-use message before users sign in to domain-joined workstations.

### Configuration

GPO name:

`GPO-Workstations-Login-Banner`

Linked to:

`RK-LAB/Computers/Workstations`

Configured under:

`Computer Configuration → Policies → Windows Settings → Security Settings → Local Policies → Security Options`

Settings configured:

| Setting | Value |
|---|---|
| Interactive logon: Message title for users attempting to log on | `RK-LAB Authorized Use Only` |
| Interactive logon: Message text for users attempting to log on | `This system is for authorized users only. Activity may be monitored for administrative and security purposes.` |

### Verification

The login banner appeared before sign-in on the Windows 11 domain-joined workstations.

Screenshot: [`phase-6-login-banner.png`](../screenshots/phase-6-login-banner.png)

Result: Pass

## GPO 2 - Local Administrators

### Purpose

Allow IT users to perform local administrative tasks on domain-joined workstations through group membership.

### Configuration

GPO name:

`GPO-Workstations-Local-Admins`

Linked to:

`RK-LAB/Computers/Workstations`

Configured under:

`Computer Configuration → Preferences → Control Panel Settings → Local Users and Groups`

A Local Group preference item was created to update the built-in local Administrators group.

Target local group:

`Administrators (built-in)`

Added member:

`RK-LAB\GG_IT_Admins`

The policy was configured to add the IT admin group without removing existing local administrator entries.

### Verification

Members of `GG_IT_Admins` were able to perform local administrative actions on workstations.

Standard non-IT users were not granted local administrator rights.

Result: Pass

## GPO 3 - Windows Update Behavior

### Purpose

Configure managed Windows Update behavior for domain-joined workstations.

The goal was to demonstrate basic workstation update management without deploying WSUS.

### Configuration

GPO name:

`GPO-Workstations-Windows-Update`

Linked to:

`RK-LAB/Computers/Workstations`

Configured under:

`Computer Configuration → Policies → Administrative Templates → Windows Components → Windows Update`

Settings configured:

| Setting | Value |
|---|---|
| Configure Automatic Updates | Enabled |
| Automatic update option | Auto download and schedule the install |
| Scheduled install day | Sunday |
| Scheduled install time | 3:00 AM |
| No auto-restart with logged on users for scheduled automatic updates installations | Enabled |
| Turn off auto-restart for updates during active hours | Enabled |
| Active hours | 8:00 AM - 5:00 PM |

### Verification

The policy was verified on `WIN11-01` using an elevated command prompt.

Command used:

`gpresult /scope computer /r`

The following applied computer GPOs were shown:

- `GPO-Workstations-Login-Banner`
- `GPO-Workstations-Local-Admins`
- `GPO-Workstations-Windows-Update`
- `Default Domain Policy`

Screenshot: [`phase-6-gp-result-computer.png`](../screenshots/phase-6-gp-result-computer.png)

Result: Pass

### Notes

This lab does not use WSUS. The policy manages Windows Update behavior for workstations but does not point clients to an internal update server.

The setting `Specify intranet Microsoft update service location` was intentionally left unconfigured because no WSUS server exists in this lab.

## Issue Encountered - Computer GPO Not Visible in gpresult

### Symptom

Running `gpresult /r` did not show Computer Settings, and the Windows Update GPO did not appear in the output.

### Checks Performed

- Confirmed `GPO-Workstations-Windows-Update` was linked to `RK-LAB/Computers/Workstations`.
- Confirmed `WIN11-01` was located in the Workstations OU.
- Confirmed the GPO was enabled and configured under Computer Configuration.
- Ran `gpupdate /force` and rebooted the workstation.
- Re-ran `gpresult` from an elevated command prompt.

### Root Cause

`gpresult /r` was initially run from a non-elevated command prompt, so computer-side policy results were not displayed.

### Fix

Opened Command Prompt as administrator and ran:

`gpresult /scope computer /r`

### Verification

The Windows Update GPO appeared under Applied Group Policy Objects for the computer.

Applied computer GPOs included:

- `GPO-Workstations-Login-Banner`
- `GPO-Workstations-Local-Admins`
- `GPO-Workstations-Windows-Update`
- `Default Domain Policy`

## GPO 4 - Mapped Drives

### Purpose

Automatically map network drives for users based on department group membership.

### Configuration

GPO name:

`GPO-Users-Mapped-Drives`

Linked to:

`RK-LAB/Users`

Configured under:

`User Configuration → Preferences → Windows Settings → Drive Maps`

Drive mappings:

| Drive | Path | Targeting |
|---|---|---|
| `P:` | `\\DC01\Public` | All users under `RK-LAB/Users` |
| `H:` | `\\DC01\Departments\HR` | `GG_HR_FileShare_RW` |
| `F:` | `\\DC01\Departments\Finance` | `GG_Finance_FileShare_RW` |
| `O:` | `\\DC01\Departments\Operations` | `GG_Operations_FileShare_RW` |

Department drives were configured with item-level targeting based on security group membership.

The following options were enabled on the Common tab where appropriate:

- Run in logged-on user's security context
- Remove this item when it is no longer applied
- Item-level targeting

### Verification

Drive mapping results:

| Test User | Department | Expected Drives | Result |
|---|---|---|---|
| `sarah.collins` | HR | `P: Public`, `H: HR` | Pass |
| `emily.carter` | Finance | `P: Public`, `F: Finance` | Pass |
| `olivia.bennett` | Operations | `P: Public`, `O: Operations` | Pass |
| `alex.morgan` | IT | `P: Public` | Pass |

Department users received only their department drive and the Public drive.

IT users were not automatically mapped to every department drive, even though they had access through `GG_IT_Admins`.

Screenshots:

- [`phase-6-drive-maps.png`](../screenshots/phase-6-drive-maps.png)
- [`phase-6-hr-drive-maps.png`](../screenshots/phase-6-hr-drive-maps.png)

Result: Pass

## GPO 5 - Password and Account Lockout Policy

### Purpose

Configure domain-level password and account lockout behavior.

### Configuration

Configured in:

`Default Domain Policy`

Linked to:

`rk-lab.local` domain root

Configured under:

`Computer Configuration → Policies → Windows Settings → Security Settings → Account Policies`

Password policy settings:

| Setting | Value |
|---|---|
| Minimum password length | 10 characters |
| Password must meet complexity requirements | Enabled |
| Maximum password age | 90 days |
| Minimum password age | 1 day |
| Enforce password history | 5 passwords remembered |

Account lockout policy settings:

| Setting | Value |
|---|---|
| Account lockout threshold | 5 invalid logon attempts |
| Account lockout duration | 15 minutes |
| Reset account lockout counter after | 15 minutes |

### Verification

The account `mark.rivera` was intentionally locked out after repeated invalid logon attempts.

Client-side message:

`The referenced account is currently locked out and may not be logged on to.`

The account lockout was confirmed in Active Directory Users and Computers.

The account was then unlocked from the Account tab in ADUC.

Result: Pass

## Account Lockout Troubleshooting Note

### Symptom

`mark.rivera` could not log in and received a lockout message.

### Checks Performed

- Confirmed repeated failed login attempts triggered the lockout.
- Opened the user account in Active Directory Users and Computers.
- Verified the account showed as locked on the Account tab.

### Root Cause

The account lockout threshold configured in the Default Domain Policy was reached.

### Fix

Unlocked the account in ADUC by selecting `Unlock account`.

### Verification

The account was able to attempt login again after being unlocked.

## GPO 6 - Standard User Restrictions

### Purpose

Restrict standard non-IT users from accessing Control Panel and PC Settings.

### Configuration

GPO name:

`GPO-Users-Standard-Restrictions`

Linked to:

`RK-LAB/Users`

Configured under:

`User Configuration → Policies → Administrative Templates → Control Panel`

Setting configured:

| Setting | Value |
|---|---|
| Prohibit access to Control Panel and PC Settings | Enabled |

### Security Filtering

A new security group was created:

`GG_Standard_Users`

Members:

- `sarah.collins`
- `mark.rivera`
- `emily.carter`
- `daniel.price`
- `olivia.bennett`
- `chris.walker`

IT users were intentionally excluded:

- `alex.morgan`
- `jamie.brooks`

Security filtering was configured so the GPO applied only to:

`GG_Standard_Users`

Delegation permissions were adjusted so the GPO could still be read during Group Policy processing.

Final permission model:

| Principal | Read | Apply Group Policy |
|---|---|---|
| `GG_Standard_Users` | Allow | Allow |
| `Authenticated Users` | Allow | Not Applied |

### Verification

| Test User | Role | Expected Result | Actual Result |
|---|---|---|---|
| `sarah.collins` | Standard user | Blocked from Control Panel / Settings | Pass |
| `alex.morgan` | IT user | Not blocked | Pass |

Result: Pass

## Issue Encountered - Security-Filtered GPO Did Not Apply

### Symptom

`GPO-Users-Standard-Restrictions` stopped applying after security filtering was changed from `Authenticated Users` to `GG_Standard_Users`.

Standard users were still able to access Control Panel and PC Settings.

### Checks Performed

- Confirmed the GPO was linked to `RK-LAB/Users`.
- Confirmed the Control Panel restriction setting was enabled.
- Confirmed standard users were members of `GG_Standard_Users`.
- Reviewed GPO security filtering.
- Reviewed GPO delegation permissions.

### Root Cause

`Authenticated Users` had been removed from security filtering, but no separate read permission had been added under Delegation.

As a result, the GPO could not be read during Group Policy processing.

### Fix

Added read permission back through Delegation while keeping `Apply group policy` limited to `GG_Standard_Users`.

### Verification

Standard users received the Control Panel and PC Settings restriction.

IT users did not receive the restriction.

## Group Policy Concepts Demonstrated

This phase demonstrated the following Group Policy concepts:

- Linking computer policies to workstation OUs
- Linking user policies to user OUs
- Difference between User Configuration and Computer Configuration
- Group Policy Preferences
- Local group management through Group Policy Preferences
- Drive mapping through Group Policy Preferences
- Item-level targeting
- Security filtering
- Delegation and read permissions
- Domain-level password and lockout policy
- Managed Windows Update behavior
- Testing policy application from client machines
- Troubleshooting failed GPO application

## Notes

Computer-side GPOs were linked to:

`RK-LAB/Computers/Workstations`

User-side GPOs were linked to:

`RK-LAB/Users`

Password and account lockout settings were configured in the `Default Domain Policy` because domain account policies are normally applied at the domain level.

The standard user restriction GPO was linked broadly to `RK-LAB/Users` but filtered to `GG_Standard_Users`, allowing IT users to be excluded without manually linking the GPO to each individual department OU.

The Windows Update GPO was linked to the Workstations OU and verified with elevated computer-side `gpresult` output.

## Phase 6 Result

Phase 6 completed successfully.

Implemented and tested:

- Login banner
- Local administrator group management
- Managed Windows Update behavior
- Mapped network drives
- Password and account lockout policy
- Standard user restrictions with security filtering
- GPO troubleshooting and documentation
