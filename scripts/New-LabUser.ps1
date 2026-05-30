<#
.SYNOPSIS
Creates one or more Active Directory lab users.

.DESCRIPTION
Creates users in the correct department OU for the rk-lab.local lab, generates
available usernames, sets temporary passwords, requires password change at next
logon, and adds users to standard and department-specific lab groups.

The script supports either a single user through parameters or bulk creation
from a CSV file. This is a lab script; do not hardcode or reuse production
passwords.

By default, the script stops if the base username already exists. Use
-AllowDuplicateNameSuffix when intentionally creating a second user with the
same first and last name.

.PARAMETER FirstName
The user's first name. Required for single-user creation.

.PARAMETER LastName
The user's last name. Required for single-user creation.

.PARAMETER Department
The target department. Valid values are IT, HR, Finance, and Operations.

.PARAMETER TemporaryPassword
The temporary password assigned to the account. The user is required to change
this password at next logon.

.PARAMETER CsvPath
Path to a CSV file for bulk user creation. Required columns are FirstName,
LastName, Department, and TemporaryPassword.

.PARAMETER AllowDuplicateNameSuffix
Allow the script to create a suffixed username such as alex.morgan2 when the
base username already exists. Without this switch, existing base usernames are
reported as skipped to avoid accidental duplicate accounts.

.EXAMPLE
.\New-LabUser.ps1 -FirstName Morgan -LastName Read -Department HR -TemporaryPassword "ChangeMe123!"

.EXAMPLE
.\New-LabUser.ps1 -FirstName Taylor -LastName Smith -Department Finance -TemporaryPassword "ChangeMe123!" -Verbose

.EXAMPLE
.\New-LabUser.ps1 -FirstName Alex -LastName Rivera -Department IT -TemporaryPassword "ChangeMe123!" -WhatIf

.EXAMPLE
.\New-LabUser.ps1 -CsvPath .\lab-users.csv -WhatIf

.EXAMPLE
.\New-LabUser.ps1 -FirstName Alex -LastName Morgan -Department IT -TemporaryPassword "ChangeMe123!" -AllowDuplicateNameSuffix
#>

[CmdletBinding(SupportsShouldProcess, DefaultParameterSetName = "SingleUser")]
param (
    [Parameter(Mandatory, ParameterSetName = "SingleUser")]
    [ValidateNotNullOrEmpty()]
    [string]$FirstName,

    [Parameter(Mandatory, ParameterSetName = "SingleUser")]
    [ValidateNotNullOrEmpty()]
    [string]$LastName,

    [Parameter(Mandatory, ParameterSetName = "SingleUser")]
    [ValidateSet("IT", "HR", "Finance", "Operations")]
    [string]$Department,

    [Parameter(Mandatory, ParameterSetName = "SingleUser")]
    [ValidateNotNullOrEmpty()]
    [ValidateLength(10, 128)]
    [string]$TemporaryPassword,

    [Parameter(Mandatory, ParameterSetName = "Csv")]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$CsvPath,

    [Parameter()]
    [switch]$AllowDuplicateNameSuffix
)

$ErrorActionPreference = "Stop"

Import-Module ActiveDirectory -ErrorAction Stop

$DomainName = "rk-lab.local"

$DepartmentConfig = @{
    "IT" = @{
        OU    = "OU=IT,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_IT_Admins"
    }
    "HR" = @{
        OU    = "OU=HR,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_HR_FileShare_RW"
    }
    "Finance" = @{
        OU    = "OU=Finance,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_Finance_FileShare_RW"
    }
    "Operations" = @{
        OU    = "OU=Operations,OU=Users,OU=_RK-LAB,DC=rk-lab,DC=local"
        Group = "GG_Operations_FileShare_RW"
    }
}

function New-LabUsername {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LastName
    )

    $CleanFirstName = ($FirstName.Trim() -replace "\s+", "")
    $CleanLastName = ($LastName.Trim() -replace "\s+", "")
    $BaseUsername = ("$CleanFirstName.$CleanLastName").ToLower() -replace "[^a-z0-9.]", ""
    $BaseUsername = $BaseUsername.Trim(".")

    if ([string]::IsNullOrWhiteSpace($BaseUsername)) {
        throw "Unable to generate a valid username from FirstName and LastName."
    }

    $Counter = 1
    $DefaultUsername = $BaseUsername.Substring(0, [Math]::Min($BaseUsername.Length, 20))
    $BaseExists = Get-ADUser -Filter "SamAccountName -eq '$DefaultUsername'" -ErrorAction SilentlyContinue

    if ($BaseExists -and -not $AllowDuplicateNameSuffix) {
        return [PSCustomObject]@{
            Username = $DefaultUsername
            Exists   = $true
        }
    }

    do {
        if ($Counter -eq 1) {
            $Suffix = ""
        }
        else {
            $Suffix = [string]$Counter
        }

        $MaxBaseLength = 20 - $Suffix.Length
        $UsernameBase = $BaseUsername.Substring(0, [Math]::Min($BaseUsername.Length, $MaxBaseLength))
        $Username = "$UsernameBase$Suffix"

        $Counter++
    } while (Get-ADUser -Filter "SamAccountName -eq '$Username'" -ErrorAction SilentlyContinue)

    return [PSCustomObject]@{
        Username = $Username
        Exists   = $false
    }
}

function Test-LabUserInput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [pscustomobject]$User
    )

    $RequiredFields = @("FirstName", "LastName", "Department", "TemporaryPassword")

    foreach ($Field in $RequiredFields) {
        if (-not $User.PSObject.Properties.Name.Contains($Field)) {
            throw "CSV row is missing required field: $Field"
        }

        if ([string]::IsNullOrWhiteSpace([string]$User.$Field)) {
            throw "Required field '$Field' is blank."
        }
    }

    if (-not $DepartmentConfig.ContainsKey($User.Department.Trim())) {
        throw "Invalid department '$($User.Department)'. Valid values are: $($DepartmentConfig.Keys -join ', ')"
    }

    if ([string]$User.TemporaryPassword -like "*`r*" -or [string]$User.TemporaryPassword -like "*`n*") {
        throw "TemporaryPassword cannot contain line breaks."
    }

    if (([string]$User.TemporaryPassword).Length -lt 10) {
        throw "TemporaryPassword must be at least 10 characters."
    }
}

function New-LabADUser {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$FirstName,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$LastName,

        [Parameter(Mandatory)]
        [ValidateSet("IT", "HR", "Finance", "Operations")]
        [string]$Department,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [ValidateLength(10, 128)]
        [string]$TemporaryPassword
    )

    $FirstName = $FirstName.Trim()
    $LastName = $LastName.Trim()
    $Department = $Department.Trim()

    $SelectedDepartment = $DepartmentConfig[$Department]
    $TargetOU = $SelectedDepartment.OU
    $DepartmentGroup = $SelectedDepartment.Group

    $UsernameResult = New-LabUsername -FirstName $FirstName -LastName $LastName
    $Username = $UsernameResult.Username
    $DisplayName = "$FirstName $LastName"
    $BaseDisplayName = "$FirstName.$LastName".ToLower()
    $UserPrincipalName = "$Username@$DomainName"

    if ($UsernameResult.Exists) {
        return [PSCustomObject]@{
            FirstName         = $FirstName
            LastName          = $LastName
            Department        = $Department
            Username          = $Username
            Name              = $DisplayName
            UserPrincipalName = $UserPrincipalName
            TargetOU          = $TargetOU
            GroupsAdded       = ""
            Status            = "Skipped: base username already exists. Use -AllowDuplicateNameSuffix to create a suffixed username."
        }
    }

    if ($Username -eq $BaseDisplayName) {
        $Name = $DisplayName
    }
    else {
        $Name = "$DisplayName ($Username)"
    }

    $StandardGroups = @(
        "GG_All_Employees",
        "GG_Standard_Users",
        $DepartmentGroup
    )

    Write-Verbose "Selected department: $Department"
    Write-Verbose "Target OU: $TargetOU"
    Write-Verbose "Generated username: $Username"
    Write-Verbose "User principal name: $UserPrincipalName"
    Write-Verbose "Groups to add: $($StandardGroups -join ', ')"

    if (-not (Get-ADOrganizationalUnit -Identity $TargetOU -ErrorAction SilentlyContinue)) {
        throw "Target OU does not exist: $TargetOU"
    }

    foreach ($Group in $StandardGroups) {
        if (-not (Get-ADGroup -Identity $Group -ErrorAction SilentlyContinue)) {
            throw "Required group does not exist: $Group"
        }
    }

    $SecurePassword = ConvertTo-SecureString $TemporaryPassword -AsPlainText -Force

    try {
        if ($PSCmdlet.ShouldProcess($Username, "Create AD user and apply group memberships")) {
            Write-Verbose "Creating AD user: $Name"

            New-ADUser `
                -Name $Name `
                -GivenName $FirstName `
                -Surname $LastName `
                -DisplayName $DisplayName `
                -SamAccountName $Username `
                -UserPrincipalName $UserPrincipalName `
                -Path $TargetOU `
                -AccountPassword $SecurePassword `
                -Enabled $true `
                -ChangePasswordAtLogon $true `
                -Department $Department

            foreach ($Group in $StandardGroups) {
                Write-Verbose "Adding $Username to $Group"
                Add-ADGroupMember -Identity $Group -Members $Username
            }

            $Status = "User created and group membership applied"
        }
        else {
            $Status = "WhatIf: no changes made"
        }

        [PSCustomObject]@{
            FirstName         = $FirstName
            LastName          = $LastName
            Department        = $Department
            Username          = $Username
            Name              = $Name
            UserPrincipalName = $UserPrincipalName
            TargetOU          = $TargetOU
            GroupsAdded       = ($StandardGroups -join ", ")
            Status            = $Status
        }
    }
    catch {
        [PSCustomObject]@{
            FirstName         = $FirstName
            LastName          = $LastName
            Department        = $Department
            Username          = $Username
            Name              = $Name
            UserPrincipalName = $UserPrincipalName
            TargetOU          = $TargetOU
            GroupsAdded       = ""
            Status            = "Failed"
            Error             = $_.Exception.Message
        }
    }
}

if ($PSCmdlet.ParameterSetName -eq "Csv") {
    $Rows = Import-Csv -LiteralPath $CsvPath

    if (-not $Rows) {
        throw "CSV file has no user rows: $CsvPath"
    }

    $RequiredHeaders = @("FirstName", "LastName", "Department", "TemporaryPassword")
    $Headers = @($Rows[0].PSObject.Properties.Name)

    foreach ($Header in $RequiredHeaders) {
        if ($Headers -notcontains $Header) {
            throw "CSV file is missing required header: $Header"
        }
    }

    foreach ($Row in $Rows) {
        Test-LabUserInput -User $Row

        New-LabADUser `
            -FirstName $Row.FirstName.Trim() `
            -LastName $Row.LastName.Trim() `
            -Department $Row.Department.Trim() `
            -TemporaryPassword $Row.TemporaryPassword.Trim() `
            -WhatIf:$WhatIfPreference `
            -Verbose:($VerbosePreference -eq "Continue")
    }
}
else {
    $User = [PSCustomObject]@{
        FirstName         = $FirstName
        LastName          = $LastName
        Department        = $Department
        TemporaryPassword = $TemporaryPassword
    }

    Test-LabUserInput -User $User

    New-LabADUser `
        -FirstName $FirstName `
        -LastName $LastName `
        -Department $Department `
        -TemporaryPassword $TemporaryPassword `
        -WhatIf:$WhatIfPreference `
        -Verbose:($VerbosePreference -eq "Continue")
}
