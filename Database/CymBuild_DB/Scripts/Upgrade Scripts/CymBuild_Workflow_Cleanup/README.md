# CymBuild Workflow Cleanup Consolidated Pack v14

This pack consolidates the workflow cleanup and UAT-to-DEV alignment scripts, including the fixes discovered during testing.

## What v14 fixes

The v14 OrganisationalUnit step stopped with:

`SCore.OrganisationalUnits has required non-default columns not included in this safe alignment script.`

That stop was correct because DEV requires additional non-null columns on `SCore.OrganisationalUnits`. v14 updates the source generator and DEV OU apply script to include:

- `ParentID`
- `AddressId`
- `ContactId`
- `OfficialAddressId`
- `OfficialContactId`
- `OrgNode`
- `DepartmentPrefix`
- `CostCentreCode`
- `DefaultSecurityGroupId`
- `QuoteThreshold`

The run order now applies `SCore.Groups` before `SCore.OrganisationalUnits`, because `DefaultSecurityGroupId` references `SCore.Groups.ID`.

## Scope

Included:

- UAT workflow cleanup
- UAT source snapshot generator
- DEV group config alignment
- DEV organisational unit dependency alignment
- DEV workflow config alignment
- validation scripts
- rollback script for workflow config alignment

Not included:

- `SCore.UserGroups`
- users
- group memberships
- `SCore.ObjectSecurity`
- runtime workflow history from `SCore.DataObjectTransition`

## Use

Follow `00_Run_Order.md`.
