# Phase 5 - Domain Join and Access Testing

## Objective

Join both Windows 11 Enterprise clients to the `rk-lab.local` domain, move the computer objects into the correct OU, and verify domain login, DNS resolution, and file share access.

## Workstations

| Hostname | IP Address | DNS Server | Domain Joined | OU |
|---|---:|---:|---|---|
| WIN11-01 | 10.10.10.21 | 10.10.10.10 | Yes | RK-LAB/Computers/Workstations |
| WIN11-02 | 10.10.10.22 | 10.10.10.10 | Yes | RK-LAB/Computers/Workstations |

## Access Test Matrix

| Test User | Department | Public | HR | Finance | Operations | Result |
|---|---|---|---|---|---|---|
| sarah.collins | HR | Allowed | Allowed | Denied | Denied | Pass |
| emily.carter | Finance | Allowed | Denied | Allowed | Denied | Pass |
| olivia.bennett | Operations | Allowed | Denied | Denied | Allowed | Pass |
| alex.morgan | IT | Allowed | Allowed | Allowed | Allowed | Pass |

## Verification Notes

Both Windows 11 clients successfully joined the `rk-lab.local` domain.

Computer objects appeared in Active Directory and were moved into:

`RK-LAB/Computers/Workstations`

Domain users were able to log into the workstations successfully.

File share testing confirmed that users had access only to the folders allowed by their group memberships.

## Evidence

The access test results are documented in the matrix above. Screenshot evidence is included for a domain user session on `WIN11-01`, showing:

- `whoami` output for `rk-lab\alex.morgan`
- `hostname` output for `WIN11-01`
- `nslookup DC01` resolving through `dc01.rk-lab.local` at `10.10.10.10`

Evidence file:

- [`phase-5-domain-join.png`](../screenshots/phase-5-domain-join.png)

## Default Domain Controller Shares

When browsing `\\DC01`, the `SYSVOL` and `NETLOGON` shares were visible. These are default domain controller shares used by Active Directory for Group Policy, scripts, and domain logon functionality. They were left unchanged.

Custom shares created for this project:

- `\\DC01\Departments`
- `\\DC01\Public`

## Result

Phase 5 completed successfully.
