# Phase 4 - File Shares and NTFS Permissions

## Objective

Create department file shares on DC01 and use Active Directory security groups to control access.

## Folder Structure

- `C:\Shares\Departments\HR`
- `C:\Shares\Departments\Finance`
- `C:\Shares\Departments\Operations`
- `C:\Shares\Public`

## Network Shares

| Local Path | Share Path | Purpose |
|---|---|---|
| `C:\Shares\Departments` | `\\DC01\Departments` | Parent share for restricted department folders |
| `C:\Shares\Public` | `\\DC01\Public` | General shared folder for all employees |

## Permission Model

Share permissions are configured broadly, while NTFS permissions are used for precise access control.

| Resource | GG_IT_Admins | GG_HR_FileShare_RW | GG_Finance_FileShare_RW | GG_Operations_FileShare_RW | GG_All_Employees |
|---|---:|---:|---:|---:|---:|
| `\\DC01\Departments\HR` | Full Control | Modify | No Access | No Access | No Access |
| `\\DC01\Departments\Finance` | Full Control | No Access | Modify | No Access | No Access |
| `\\DC01\Departments\Operations` | Full Control | No Access | No Access | Modify | No Access |
| `\\DC01\Public` | Full Control | Modify via All Employees | Modify via All Employees | Modify via All Employees | Modify |

## Design Notes

Department folder permissions are assigned to security groups rather than individual users. This makes access easier to manage because user access can be changed by modifying group membership.

The `Departments` share acts as a parent share. Individual department folders use NTFS permissions to restrict access.

The `Public` share is available to all employees through the `GG_All_Employees` group.

## Verification

- `\\DC01` shows the `Departments` and `Public` shares.
- Department folders have restricted NTFS permissions.
- Public folder allows all employees to modify files.
- Full user access testing will be completed after domain-joining Windows 11 clients.

Screenshots:

- [`phase-4-operations-folder-permissions.png`](../screenshots/phase-4-operations-folder-permissions.png)
- [`phase-4-public-folder-permissions.png`](../screenshots/phase-4-public-folder-permissions.png)

## Issue Encountered - Public Share Not Visible

### Symptom
Browsing to `\\DC01` showed `Departments`, `netlogon`, and `sysvol`, but the custom `Public` share was missing.

### Checks Performed
- Confirmed the local folder `C:\Shares\Public` existed.
- Confirmed NTFS permissions were configured correctly.
- Checked the folder's Sharing tab.

### Root Cause
The `C:\Shares\Public` folder had NTFS permissions configured but had not been shared over the network.

### Fix
Enabled sharing on `C:\Shares\Public` and configured the share name as `Public`.

### Verification
Browsing to `\\DC01` showed both custom shares:
- `Departments`
- `Public`

Default domain controller shares also appeared:
- `netlogon`
- `sysvol`
