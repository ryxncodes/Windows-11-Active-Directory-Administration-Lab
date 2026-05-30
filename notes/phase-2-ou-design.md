# Phase 2 - Active Directory OU Design

## Objective

Create a clean Active Directory OU structure for a small Windows domain lab. The goal is to separate users, computers, groups, service accounts, and disabled accounts in a way that supports administration and future Group Policy targeting.

## OU Structure

- RK-LAB
  - Computers
    - Workstations
    - Servers
  - Users
    - IT
    - HR
    - Finance
    - Operations
    - Service Accounts
    - Disabled Users
  - Groups

## Design Notes

The top-level `RK-LAB` OU separates custom lab objects from default Active Directory containers such as `Users`, `Computers`, `Builtin`, and `Domain Controllers`.

Computer objects are separated into Workstations and Servers so different Group Policies can be applied based on device role.

User accounts are organized by department to make administration easier and to allow department-specific policies later.

Security groups are stored in a dedicated Groups OU. Groups will be used for access control, while OUs will be used for organization and Group Policy targeting.

## OU vs Security Group

An OU controls where an object lives in Active Directory and what Group Policies may apply to it.

A security group controls what resources a user or computer can access.

Example: an HR user belongs in the `Users/HR` OU, but receives access to the HR file share through membership in `GG_HR_FileShare_RW`.

## Screenshot

See: [`screenshots/phase-2-ad-ou-structure.png`](../screenshots/phase-2-ad-ou-structure.png)
