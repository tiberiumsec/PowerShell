<#
.SYNOPSIS
    Gets all permissions set on all Organizational Units (OU).

.LINKS
    https://gallery.technet.microsoft.com/Active-Directory-OU-1d09f989
#>

Import-Module ActiveDirectory

$filename = '.\OU_Permissions.csv'

# This array will hold the report output.
$report = @()

$schemaIDGUID = @{}
### NEED TO RECONCILE THE CONFLICTS ###
$ErrorActionPreference = 'SilentlyContinue'
Get-ADObject -SearchBase (Get-ADRootDSE).schemaNamingContext -LDAPFilter '(schemaIDGUID=*)' -Properties name, schemaIDGUID |
 ForEach-Object {$schemaIDGUID.add([System.GUID]$_.schemaIDGUID,$_.name)}
Get-ADObject -SearchBase "CN=Extended-Rights,$((Get-ADRootDSE).configurationNamingContext)" -LDAPFilter '(objectClass=controlAccessRight)' -Properties name, rightsGUID |
 ForEach-Object {$schemaIDGUID.add([System.GUID]$_.rightsGUID,$_.name)}
$ErrorActionPreference = 'Continue'

# Get a list of all OUs.  Add in the root containers for good measure (users, computers, etc.).
$OUs  = @(Get-ADDomain | Select-Object -ExpandProperty DistinguishedName)
$OUs += Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty DistinguishedName
$OUs += Get-ADObject -SearchBase (Get-ADDomain).DistinguishedName -SearchScope OneLevel -LDAPFilter '(objectClass=container)' | Select-Object -ExpandProperty DistinguishedName

# Loop through each of the OUs and retrieve their permissions.
# Add report columns to contain the OU path and string names of the ObjectTypes.
ForEach ($OU in $OUs) {
    $report += Get-Acl -Path "AD:\$OU" |
     Select-Object -ExpandProperty Access | 
     Select-Object @{name='organizationalUnit';expression={$OU}}, `
                   @{name='objectTypeName';expression={if ($_.objectType.ToString() -eq '00000000-0000-0000-0000-000000000000') {'All'} Else {$schemaIDGUID.Item($_.objectType)}}}, `
                   @{name='inheritedObjectTypeName';expression={$schemaIDGUID.Item($_.inheritedObjectType)}}, `
                   *
}

# Dump the raw report out to a CSV file for analysis in Excel.
$report | Select OrganizationalUnit, IdentityReference, ObjectTypeName, InheritedObjectTypeName, ActiveDirectoryRights, InheritanceType, AccessControlType, IsInherited, InheritanceFlags, ProgationFlags, ObjectType, InheritedObjectType, ObjectFlags | Export-Csv -Path $filename -NoTypeInformation
# Start-Process ".\OU_Permissions.csv"

###############################################################################
# Various reports of interest
###############################################################################
break

# Show only explicitly assigned permissions by Group and OU
$report |
 Where-Object {-not $_.IsInherited} |
 Select-Object IdentityReference, OrganizationalUnit -Unique |
 Sort-Object IdentityReference

# Show explicitly assigned permissions for a user or group
$filter = Read-Host "Enter the user or group name to search in OU permissions"
$report |
 Where-Object {$_.IdentityReference -like "*$filter*"} |
 Select-Object IdentityReference, OrganizationalUnit, IsInherited -Unique |
 Sort-Object IdentityReference
