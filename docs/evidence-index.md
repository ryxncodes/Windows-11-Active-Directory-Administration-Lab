# Evidence Index

This file maps the lab documentation to the available validation evidence in the repository.

## Screenshots

| File | Phase | Evidence |
|---|---|---|
| [`screenshots/phase-2-ad-ou-structure.png`](../screenshots/phase-2-ad-ou-structure.png) | Phase 2 | Active Directory OU structure for `RK-LAB` |
| [`screenshots/phase-3-groups.png`](../screenshots/phase-3-groups.png) | Phase 3 | Security groups created for department access control |
| [`screenshots/phase-4-operations-folder-permissions.png`](../screenshots/phase-4-operations-folder-permissions.png) | Phase 4 | Operations folder NTFS permissions |
| [`screenshots/phase-4-public-folder-permissions.png`](../screenshots/phase-4-public-folder-permissions.png) | Phase 4 | Public folder NTFS permissions |
| [`screenshots/phase-6-login-banner.png`](../screenshots/phase-6-login-banner.png) | Phase 6 | Login banner applied through Group Policy |
| [`screenshots/phase-6-gp-result-computer.png`](../screenshots/phase-6-gp-result-computer.png) | Phase 6 | Computer-side GPOs visible in `gpresult` |
| [`screenshots/phase-6-drive-maps.png`](../screenshots/phase-6-drive-maps.png) | Phase 6 | Drive mapping Group Policy Preferences configuration |
| [`screenshots/phase-6-hr-drive-maps.png`](../screenshots/phase-6-hr-drive-maps.png) | Phase 6 | HR user received expected mapped drives |

## Documented Validation

| Phase | Validation Documented |
|---|---|
| [Phase 1](../notes/phase-1-foundation-checks.md) | DC hostname, static IP, DNS zone, ADUC, client connectivity, VirtualBox network fix |
| [Phase 2](../notes/phase-2-ou-design.md) | OU design and separation of users, computers, groups, service accounts, and disabled accounts |
| [Phase 3](../notes/phase-3-users-and-groups.md) | Department users, standard user group, and security groups |
| [Phase 4](../notes/phase-4-file-shares-and-ntfs-permissions.md) | Department and public share permissions |
| [Phase 5](../notes/phase-5-domain-join-and-access-testing.md) | Domain join, workstation OU placement, user login, and file share access matrix |
| [Phase 6](../notes/phase-6-group-policy.md) | Login banner, local admin membership, Windows Update behavior, mapped drives, lockout policy, and standard user restrictions |

## Evidence Gaps To Add Later

- Phase 5 screenshot showing Windows 11 domain membership.
- Phase 5 screenshot or command output showing `whoami` for a domain user.
- Phase 5 screenshot or command output showing DNS lookup against `DC01`.
- Phase 5 screenshots showing allowed and denied share access by department user.
- Sanitized GPO HTML reports for each custom GPO.
