# Windows 11 Active Directory Administration Lab

Status: Built and validated

This project documents a hands-on Windows Active Directory lab built for junior systems administration practice. The environment includes a Windows Server domain controller, two Windows 11 domain clients, DNS, SMB file shares, NTFS permissions, Group Policy, domain user administration, and PowerShell automation.

The goal of the project is to demonstrate practical administration skills in a format that can be reviewed quickly by recruiters while still providing enough technical depth for an IT manager or systems administrator.

## Highlights

- Built an isolated VirtualBox domain lab for `rk-lab.local`.
- Configured `DC01` with Active Directory Domain Services, DNS, SMB shares, and Group Policy.
- Joined `WIN11-01` and `WIN11-02` to the domain.
- Created a structured OU design for users, workstations, servers, groups, service accounts, and disabled users.
- Created department users and security groups for IT, HR, Finance, and Operations.
- Configured department file shares with group-based NTFS permissions.
- Configured GPOs for login banners, mapped drives, local administrator membership, Windows Update behavior, standard user restrictions, and account lockout policy.
- Wrote PowerShell scripts for lab health checks, user creation, stale account reporting, account disablement, group membership reporting, GPO backup, and stale local profile cleanup.
- Validated the lab with `Test-ADLabHealth.ps1`: `PASS=31 WARN=0 FAIL=0`.

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

## Repository Guide

| Path | Purpose |
|---|---|
| [topology/ip-plan.md](topology/ip-plan.md) | Network, host, domain, and DNS plan |
| [notes/](notes/) | Phase-by-phase implementation and troubleshooting notes |
| [screenshots/](screenshots/) | Visual evidence from ADUC, permissions, mapped drives, and GPO validation |
| [scripts/](scripts/) | PowerShell administration and validation scripts |
| [scripts/outputs/](scripts/outputs/) | Script output screenshots, CSV reports, and GPO backup evidence |
| [docs/evidence-index.md](docs/evidence-index.md) | Index of screenshots and script output evidence |
| [docs/script-safety.md](docs/script-safety.md) | Safety notes for scripts that create, disable, move, remove, or export data |
| [docs/troubleshooting.md](docs/troubleshooting.md) | Troubleshooting runbook for common AD, DNS, GPO, drive map, and permission issues |

## Automation Evidence

The PowerShell scripts are the strongest technical part of this project. They show repeatable administration tasks, safe execution patterns, validation checks, and exportable evidence.

| Script | Purpose | Evidence |
|---|---|---|
| [Test-ADLabHealth.ps1](scripts/Test-ADLabHealth.ps1) | Checks DC reachability, DNS, SMB shares, OUs, groups, and GPO visibility | [Health check output](scripts/outputs/Test-ADLabHealth-Output.png) |
| [New-LabUser.ps1](scripts/New-LabUser.ps1) | Creates single or CSV-based department users with OU placement and group membership | [WhatIf output](scripts/outputs/New-LabUser-Output.png) |
| [Get-LabGroupMembershipReport.ps1](scripts/Get-LabGroupMembershipReport.ps1) | Exports membership for expected lab security groups | [CSV output](scripts/outputs/group-membership-report.csv) |
| [Get-StaleADUsers.ps1](scripts/Get-StaleADUsers.ps1) | Reports inactive or never-logged-on enabled AD users | [CSV output](scripts/outputs/stale-users.csv) |
| [Disable-StaleADUsers.ps1](scripts/Disable-StaleADUsers.ps1) | Disables stale users and can move them to the Disabled Users OU | Supports `-WhatIf` and `-Verbose` |
| [Backup-LabGPOs.ps1](scripts/Backup-LabGPOs.ps1) | Creates timestamped backups of expected lab GPOs using Microsoft `Backup-GPO` | [GPO backup output](scripts/outputs/gpo-backups/) |
| [Remove-StaleLocalProfiles.ps1](scripts/Remove-StaleLocalProfiles.ps1) | Removes stale local Windows profiles from endpoints | Supports `-WhatIf`; skips special and loaded profiles |

Example evidence commands:

```powershell
.\Test-ADLabHealth.ps1 -Verbose
.\New-LabUser.ps1 -FirstName Morgan -LastName Read -Department HR -TemporaryPassword "ChangeMe123!" -WhatIf -Verbose
.\Get-LabGroupMembershipReport.ps1 -ExportCsvPath .\outputs\group-membership-report.csv
.\Get-StaleADUsers.ps1 -DaysInactive 180 -IncludeNeverLoggedOn -NeverLoggedOnGraceDays 14 -ExportCsvPath .\outputs\stale-users.csv
.\Backup-LabGPOs.ps1 -BackupRoot .\outputs\gpo-backups -Verbose
.\Disable-StaleADUsers.ps1 -DaysInactive 180 -IncludeNeverLoggedOn -NeverLoggedOnGraceDays 14 -WhatIf -Verbose
.\Remove-StaleLocalProfiles.ps1 -DaysInactive 180 -DomainNetbiosName RK-LAB -WhatIf -Verbose
```

## Validation Summary

Key validation performed in the lab:

- Confirmed `DC01` static IP and DNS configuration.
- Verified the `rk-lab.local` DNS forward lookup zone.
- Confirmed Windows 11 clients could reach `DC01` by IP and hostname.
- Joined `WIN11-01` and `WIN11-02` to the domain.
- Verified domain users could sign in to Windows 11 clients and resolve `DC01` through lab DNS.
- Tested department share access for HR, Finance, Operations, and IT users.
- Confirmed denied access for users outside the expected security groups.
- Ran elevated `gpresult /scope computer /r` to confirm computer-side GPO application.
- Verified mapped drives using department user logons.
- Tested account lockout behavior after repeated failed sign-in attempts.
- Generated group membership, stale account, new-user `-WhatIf`, and GPO backup evidence.

## Screenshots

| Screenshot | Demonstrates |
|---|---|
| [phase-2-ad-ou-structure.png](screenshots/phase-2-ad-ou-structure.png) | Active Directory OU structure |
| [phase-3-groups.png](screenshots/phase-3-groups.png) | Security groups created for access control |
| [phase-4-operations-folder-permissions.png](screenshots/phase-4-operations-folder-permissions.png) | Department NTFS permission configuration |
| [phase-4-public-folder-permissions.png](screenshots/phase-4-public-folder-permissions.png) | Public share NTFS permission configuration |
| [phase-5-domain-join.png](screenshots/phase-5-domain-join.png) | Domain user session on `WIN11-01` with DNS resolution through `DC01` |
| [phase-6-login-banner.png](screenshots/phase-6-login-banner.png) | Login banner GPO result |
| [phase-6-gp-result-computer.png](screenshots/phase-6-gp-result-computer.png) | Computer-side GPO validation |
| [phase-6-drive-maps.png](screenshots/phase-6-drive-maps.png) | Drive map Group Policy Preferences configuration |
| [phase-6-hr-drive-maps.png](screenshots/phase-6-hr-drive-maps.png) | HR user mapped drive result |

## Phase Notes

| Phase | Focus |
|---|---|
| [Phase 1](notes/phase-1-foundation-checks.md) | Foundation checks, DC setup, DNS, client connectivity |
| [Phase 2](notes/phase-2-ou-design.md) | OU design |
| [Phase 3](notes/phase-3-users-and-groups.md) | Users and security groups |
| [Phase 4](notes/phase-4-file-shares-and-ntfs-permissions.md) | SMB shares and NTFS permissions |
| [Phase 5](notes/phase-5-domain-join-and-access-testing.md) | Domain join and access testing |
| [Phase 6](notes/phase-6-group-policy.md) | Group Policy configuration and troubleshooting |
