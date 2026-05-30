# Windows 11 Active Directory Administration Lab

Status: In Progress

This project documents a small Windows domain lab built to practice junior systems administration work: Active Directory administration, DNS, OU design, user and group management, file shares, NTFS permissions, Group Policy, domain-joined Windows clients, troubleshooting, and PowerShell automation.

The goal is to show practical, hands-on administration work in a clear format that a recruiter can scan and an IT manager can review for technical depth.

## Environment

| Component | Details |
|---|---|
| Hypervisor | VirtualBox |
| Network type | Internal Network |
| Internal network name | `ADLab` |
| Domain | `rk-lab.local` |
| Domain controller | `DC01` |
| Client systems | `WIN11-01`, `WIN11-02` |
| Core services | AD DS, DNS, SMB file shares, Group Policy |

## IP Plan

| Hostname | Role | IP Address | DNS Server |
|---|---|---:|---:|
| `DC01` | Domain Controller, DNS, file shares, GPOs | `10.10.10.10` | `10.10.10.10` |
| `WIN11-01` | Windows 11 domain client | `10.10.10.21` | `10.10.10.10` |
| `WIN11-02` | Windows 11 domain client | `10.10.10.22` | `10.10.10.10` |

The lab uses the isolated `10.10.10.0/24` subnet. Clients use `DC01` for DNS so they can resolve the internal Active Directory domain.

Full network notes are documented in [topology/ip-plan.md](topology/ip-plan.md).

## Implemented Features

- Built an isolated Windows domain environment for `rk-lab.local`.
- Configured `DC01` with AD DS, DNS, and SMB file shares.
- Created a structured OU layout for users, computers, groups, service accounts, and disabled accounts.
- Created department-based users and security groups for IT, HR, Finance, and Operations.
- Configured department file shares with group-based NTFS permissions.
- Joined Windows 11 clients to the domain and moved computer objects into the workstation OU.
- Validated user logons, DNS behavior, domain join status, and file share access.
- Configured Group Policy for login banners, mapped drives, local administrators, Windows Update behavior, standard user restrictions, and account lockout policy.
- Troubleshot real lab issues, including domain controller rename problems, VirtualBox network attachment, missing shares, and GPO filtering/read permission problems.
- Added a PowerShell helper script for creating lab users with department-based OU placement and group membership.

## Repository Structure

| Path | Purpose |
|---|---|
| [topology/ip-plan.md](topology/ip-plan.md) | Network, host, domain, and DNS plan |
| [notes/](notes/) | Phase-by-phase implementation and troubleshooting notes |
| [screenshots/](screenshots/) | Visual evidence from ADUC, permissions, mapped drives, and GPO validation |
| [scripts/New-LabUser.ps1](scripts/New-LabUser.ps1) | PowerShell helper for creating department users individually or from CSV |
| [scripts/Test-ADLabHealth.ps1](scripts/Test-ADLabHealth.ps1) | Non-destructive health checks for AD, DNS, SMB shares, OUs, groups, and GPO visibility |
| [scripts/Get-StaleADUsers.ps1](scripts/Get-StaleADUsers.ps1) | Read-only report of stale enabled AD users |
| [scripts/Disable-StaleADUsers.ps1](scripts/Disable-StaleADUsers.ps1) | Disables stale AD users with `-WhatIf` support |
| [scripts/Get-LabGroupMembershipReport.ps1](scripts/Get-LabGroupMembershipReport.ps1) | Exports membership for expected lab security groups |
| [scripts/Backup-LabGPOs.ps1](scripts/Backup-LabGPOs.ps1) | Creates timestamped backups of expected lab GPOs |
| [scripts/Remove-StaleLocalProfiles.ps1](scripts/Remove-StaleLocalProfiles.ps1) | Removes stale local Windows profiles with `-WhatIf` support |
| [docs/evidence-index.md](docs/evidence-index.md) | Index of screenshots and validation evidence |
| [docs/script-safety.md](docs/script-safety.md) | Safety notes for scripts that create, disable, or remove data |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Troubleshooting runbook for common AD, DNS, GPO, drive map, and permission issues |

## Validation Steps

Key validation performed in the lab:

- Confirmed `DC01` static IP and DNS configuration.
- Verified the `rk-lab.local` DNS forward lookup zone.
- Confirmed Windows 11 clients could reach `DC01` by IP and hostname.
- Joined `WIN11-01` and `WIN11-02` to the domain.
- Verified domain users could sign in to Windows 11 clients.
- Tested department share access with HR, Finance, Operations, and IT users.
- Confirmed denied access for users outside the expected security groups.
- Ran elevated `gpresult /scope computer /r` to confirm computer-side GPO application.
- Verified mapped drives using department user logons.
- Tested account lockout behavior after repeated failed sign-in attempts.

Detailed validation notes are documented by phase:

| Phase | Focus |
|---|---|
| [Phase 1](notes/phase-1-foundation-checks.md) | Foundation checks, DC setup, DNS, client connectivity |
| [Phase 2](notes/phase-2-ou-design.md) | OU design |
| [Phase 3](notes/phase-3-users-and-groups.md) | Users and security groups |
| [Phase 4](notes/phase-4-file-shares-and-ntfs-permissions.md) | SMB shares and NTFS permissions |
| [Phase 5](notes/phase-5-domain-join-and-access-testing.md) | Domain join and access testing |
| [Phase 6](notes/phase-6-group-policy.md) | Group Policy configuration and troubleshooting |

## Screenshots

| Screenshot | Demonstrates |
|---|---|
| [phase-2-ad-ou-structure.png](screenshots/phase-2-ad-ou-structure.png) | Active Directory OU structure |
| [phase-3-groups.png](screenshots/phase-3-groups.png) | Security groups created for access control |
| [phase-4-operations-folder-permissions.png](screenshots/phase-4-operations-folder-permissions.png) | Department NTFS permission configuration |
| [phase-4-public-folder-permissions.png](screenshots/phase-4-public-folder-permissions.png) | Public share NTFS permission configuration |
| [phase-6-login-banner.png](screenshots/phase-6-login-banner.png) | Login banner GPO result |
| [phase-6-gp-result-computer.png](screenshots/phase-6-gp-result-computer.png) | Computer-side GPO validation |
| [phase-6-drive-maps.png](screenshots/phase-6-drive-maps.png) | Drive map GPO configuration |
| [phase-6-hr-drive-maps.png](screenshots/phase-6-hr-drive-maps.png) | HR user mapped drive result |

## Evidence Status

| Area | Status |
|---|---|
| OU structure | Screenshot included |
| Security groups | Screenshot included |
| NTFS permissions | Screenshots included |
| Group Policy configuration/results | Screenshots included for login banner, computer `gpresult`, and drive maps |
| Domain join and access testing | Documented in notes; Phase 5 screenshots still needed |
| Automation scripts | Syntax-checked with PowerShell; domain-dependent scripts still need lab execution evidence |

## Automation

PowerShell scripts in this repository have been syntax-checked. Scripts that require a domain controller, RSAT modules, or Windows profile data should still be tested inside the Windows lab before being treated as operational tools.

The repository includes [scripts/New-LabUser.ps1](scripts/New-LabUser.ps1), a PowerShell script that:

- Accepts first name, last name, department, and temporary password.
- Supports CSV input with required-field validation.
- Generates an available `SamAccountName`.
- Places the account in the correct department OU.
- Sets `ChangePasswordAtLogon`.
- Adds the account to standard and department-specific groups.
- Supports `-WhatIf` for safer testing.

Example:

```powershell
.\New-LabUser.ps1 -FirstName Morgan -LastName Read -Department HR -TemporaryPassword "ChangeMe123!" -WhatIf
```

Health check example:

```powershell
.\Test-ADLabHealth.ps1 -Verbose
```

Stale profile cleanup example:

```powershell
.\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -DomainNetbiosName RK-LAB -WhatIf
```

Review [docs/script-safety.md](docs/script-safety.md) before running scripts that create, disable, move, or remove data.

## Future Improvements

- Add Phase 5 screenshots for domain join verification, `whoami`, DNS lookup, and allowed/denied share access.
- Add and document DHCP scope details if DHCP becomes part of the lab design.
- Export and include sanitized GPO reports for each custom GPO.
- Add a workstation build checklist for repeatable VM setup.
- Add PowerShell scripts for creating OUs, groups, shares, and baseline GPOs.
- Add a cleanup/reset guide for rebuilding the lab from a clean baseline.
