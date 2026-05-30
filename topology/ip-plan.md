# IP Plan

## Lab Network

| Item | Value |
|---|---|
| Hypervisor | VirtualBox |
| Network Type | Internal Network |
| Internal Network Name | `ADLab` |
| Subnet | `10.10.10.0/24` |
| Default Gateway | Not configured / isolated lab network |
| Domain | `rk-lab.local` |
| DNS Server | `10.10.10.10` |

## Hosts

| Hostname | Role | IP Address | DNS Server | Notes |
|---|---|---:|---:|---|
| `DC01` | Domain Controller, DNS, file shares | `10.10.10.10` | `10.10.10.10` | Hosts AD DS, DNS, SMB shares, and GPOs |
| `WIN11-01` | Windows 11 workstation | `10.10.10.21` | `10.10.10.10` | Domain-joined client |
| `WIN11-02` | Windows 11 workstation | `10.10.10.22` | `10.10.10.10` | Domain-joined client |

## DNS Design

All domain-joined clients use `DC01` as their DNS server.

This is required because Active Directory relies on DNS for domain controller discovery, authentication, domain join, and Group Policy processing.

Public DNS servers such as `8.8.8.8` or `1.1.1.1` are not used by clients in this isolated lab because they cannot resolve the internal `rk-lab.local` domain.

## Network Notes

The lab uses a VirtualBox Internal Network named `ADLab`, which isolates the lab VMs from the host network and the internet.

The default gateway is intentionally left blank because the lab does not currently require outbound routing.

If internet access is added later, routing/NAT should be documented separately.
