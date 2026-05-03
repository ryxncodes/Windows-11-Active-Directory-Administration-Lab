# Phase 3 - Users and Groups

## Objective

Create a small set of realistic Active Directory user accounts and security groups for the `rk-lab.local` domain.

The purpose of this phase is to practice basic user administration and demonstrate group-based access control. Users are organized by department in OUs, while security groups are used to control access to resources such as department file shares.

## Groups Created

All groups were created in:

`RK-LAB/Groups`

| Group Name | Scope | Type | Purpose |
|---|---|---|---|
| `GG_IT_Admins` | Global | Security | IT administrator access for lab administration tasks |
| `GG_HR_FileShare_RW` | Global | Security | Read/write access to the HR department file share |
| `GG_Finance_FileShare_RW` | Global | Security | Read/write access to the Finance department file share |
| `GG_Operations_FileShare_RW` | Global | Security | Read/write access to the Operations department file share |
| `GG_All_Employees` | Global | Security | General group for all standard employee accounts |

## User Accounts Created

Each department has two test users. Users were created in their department-specific OU and assigned a temporary password.

| Name | Username | Department | OU | Group Memberships |
|---|---|---|---|---|
| Alex Morgan | `alex.morgan` | IT | `RK-LAB/Users/IT` | `GG_All_Employees`, `GG_IT_Admins` |
| Jamie Brooks | `jamie.brooks` | IT | `RK-LAB/Users/IT` | `GG_All_Employees`, `GG_IT_Admins` |
| Sarah Collins | `sarah.collins` | HR | `RK-LAB/Users/HR` | `GG_All_Employees`, `GG_HR_FileShare_RW` |
| Mark Rivera | `mark.rivera` | HR | `RK-LAB/Users/HR` | `GG_All_Employees`, `GG_HR_FileShare_RW` |
| Emily Carter | `emily.carter` | Finance | `RK-LAB/Users/Finance` | `GG_All_Employees`, `GG_Finance_FileShare_RW` |
| Daniel Price | `daniel.price` | Finance | `RK-LAB/Users/Finance` | `GG_All_Employees`, `GG_Finance_FileShare_RW` |
| Olivia Bennett | `olivia.bennett` | Operations | `RK-LAB/Users/Operations` | `GG_All_Employees`, `GG_Operations_FileShare_RW` |
| Chris Walker | `chris.walker` | Operations | `RK-LAB/Users/Operations` | `GG_All_Employees`, `GG_Operations_FileShare_RW` |

## Account Configuration Notes

All user accounts were created with temporary passwords.

The accounts are intended to simulate normal employee accounts in a small business environment. Department membership is represented by OU placement, while access rights are assigned through security group membership.

## Group-Based Access Control

This lab uses security groups for permissions instead of assigning permissions directly to individual users.

For example, HR users are members of `GG_HR_FileShare_RW`. When the HR file share is created later, permissions will be assigned to `GG_HR_FileShare_RW` rather than directly to `sarah.collins` or `mark.rivera`.

This approach is easier to manage because access can be changed by adding or removing users from groups instead of modifying permissions on each resource.

## OU vs Security Group

OUs and security groups serve different purposes:

| Object | Primary Use |
|---|---|
| Organizational Unit | Organizes AD objects and allows Group Policy targeting |
| Security Group | Assigns permissions and access to resources |

Example:

A user named Sarah Collins belongs in the `RK-LAB/Users/HR` OU because she is an HR employee. She receives access to HR resources because she is a member of `GG_HR_FileShare_RW`.
## Notes for Later Phases

These groups will be used in Phase 4 when department file shares and NTFS permissions are configured.

Expected access model:

| Resource | Group With Access |
|---|---|
| HR share | `GG_HR_FileShare_RW` |
| Finance share | `GG_Finance_FileShare_RW` |
| Operations share | `GG_Operations_FileShare_RW` |
| IT administration | `GG_IT_Admins` |
| General employee resources | `GG_All_Employees` |
