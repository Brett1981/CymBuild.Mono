# CymBuild Workflow Cleanup Discovery and Remediation Pack

Generated from `Workflows.zip` UAT export.

## Scope analysed

This pack analysed the supplied SCore workflow export files only. The export contains workflow configuration, workflow history and the exported SCore workflow procedures/functions. It does **not** include every possible CymBuild table, all metadata tables, all UI manifests, or the full live codebase. For that reason the SQL scripts include runtime dependency discovery and validation gates which must be run against the target database before the cleanup is applied.

## Executive findings

|Object|Rows parsed|RowStatus summary|
|---|---|---|
|Workflow|52|1=18, 254=34|
|WorkflowStatus|52|1=51, 254=1|
|WorkflowTransition|454|1=258, 254=196|
|WorkflowStatusNotificationGroups|51|1=50, 254=1|
|WorkflowNotificationQueue|239|n/a=239|
|WorkflowNotificationQueueErrorLog|664|n/a=664|
|EntityTypes|201|0=25, 1=169, 254=7|
|DataObjectTransition|56586|1=56411, 254=175|
|DataObjects|1631575|see runtime discovery by EntityTypeId|


Key findings:

- There are 34 hidden `SCore.Workflow` rows (`RowStatus = 254`). All exported transitions under those workflows are also hidden, and no exported notification-group rows reference those hidden workflows.
- There is 1 hidden `SCore.WorkflowStatus` row: ID 41, `Ready to Send`, with no exported `DataObjectTransition` usage.
- There are 196 hidden `SCore.WorkflowTransition` rows.
- There is 1 hidden `SCore.WorkflowStatusNotificationGroups` row: ID 57, with an orphan `WorkflowStatusGuid`.
- There are active duplicate status names that should be rationalised before final deletion: `Declined`, `Rejected`, `Ready to Send`, `Quoting`, and `New`.
- `SCore.DataObjectTransitionUpsert` contains a hard-coded Ready to Send status GUID: `02A2237F-2AE7-4E05-926F-38E8B7D050A0`. This makes status ID 14 the safest retained `Ready to Send` record unless that procedure is deliberately changed.
- `SCore.DataObjectTransition` contains 56,586 history rows; this pack does not delete workflow history. Duplicate status references are migrated by ID only so the history rows remain intact.

## Proposed duplicate status mapping

|Entity Type|Duplicate ID|Duplicate GUID|Duplicate Name|Retained ID|Retained GUID|Retained Name|Transition.Status refs|Transition.Old refs|Current latest refs|Total exported refs|Reason|
|---|---|---|---|---|---|---|---|---|---|---|---|
|WorkflowStatus|37|b9ba4510-6358-4c0a-bba1-5feb33c54f84|Declined|3|708c00e6-f45f-4cb2-8e91-a80b8b8e802e|Declined|85|10|74|101|Duplicate active status name; retained canonical predefined Declined status.|
|WorkflowStatus|53|85b522aa-134c-4e6c-884a-ff7264d7dd2e|Rejected|8|0a6a71f7-b39f-4213-997e-2b3a13b6144c|Rejected|1301|634|671|1974|Duplicate active status name; retained canonical Rejected status and expanded ShowInEnquiries.|
|WorkflowStatus|52|5c9cd674-7520-44d2-9464-2a681f2f2ba4|Ready to Send|14|02a2237f-2ae7-4e05-926f-38e8b7d050a0|Ready to Send|1150|939|214|2212|Duplicate active Ready to Send; retained canonical GUID used by DataObjectTransitionUpsert validation.|
|WorkflowStatus|29|b88f95c2-41c9-4cc6-ad9f-d9223c4e852a|Quoting|50|9a60f983-24ba-4733-907e-c5cce0b691cb|Quoting|4728|5185|0|9952|Duplicate active Quoting; retained status has both enquiry and quote visibility.|
|WorkflowStatus|33|9e0a10c7-94a0-4e25-afb1-14240d906c12|New|48|3dab4339-a1c0-4abe-860a-4915a6cf94b6|New|746|751|0|1534|Duplicate active New; retained status has enquiry, quote and job visibility.|
|WorkflowStatus|41|6ed4279a-e299-4d33-8ed5-cb8b78b3f13d|Ready to Send|14|02a2237f-2ae7-4e05-926f-38e8b7d050a0|Ready to Send|0|0|0|0|Hidden duplicate Ready to Send with no exported runtime usage.|


## Active duplicate workflow transitions

|Entity Type|Duplicate ID|Duplicate GUID|Duplicate transition|Retained ID|Retained GUID|Reason|
|---|---|---|---|---|---|---|
|WorkflowTransition|395|93e30a29-5c7a-4868-8566-90c0512db43a|Building Envelope (Enquiries): Approved For Quote -> Ready for Quote|242|58b7afb9-1363-4cc2-a1a7-2fa0cfbd5b30|Active duplicate transition key; retain lower ID / richer description.|
|WorkflowTransition|349|303b83f3-59ac-4fe5-9729-8e4106950eab|Fire Engineering (Quotes): Sent -> Rejected|284|ed383530-8bff-450f-9595-826a67abb5d4|Active duplicate transition key; retain lower ID / richer description.|
|WorkflowTransition|439|d5dacc24-8041-4343-93d2-a52019eae79e|Building Safety Consultancy (Quotes): Sent -> Rejected|423|4c6471ec-ee67-40b5-89a5-41860e43f0f3|Active duplicate transition key; retain lower ID / richer description.|


## Hidden records proposed for removal after validation

|Entity|Hidden rows|
|---|---|
|Workflow|34|
|WorkflowStatus|1|
|WorkflowTransition|196|
|WorkflowStatusNotificationGroups|1|


The script removes hidden workflow configuration rows only after reference migration and validation. It does **not** remove `SCore.DataObjectTransition` rows, even when they have `RowStatus = 254`, because those rows are workflow audit/history.

## Orphan findings from supplied export

|Table|Row/Rows|Column|Value|Finding|
|---|---|---|---|---|
|WorkflowStatusNotificationGroups|-1|WorkflowStatusGuid|ba2566ef-f0eb-481c-8edc-b17b34a3359a|No matching SCore.WorkflowStatus.Guid|
|WorkflowStatusNotificationGroups|57|WorkflowStatusGuid|39872dc8-bc36-43a6-aa63-1a8e5fd7f46a|No matching SCore.WorkflowStatus.Guid|


Notes:

- `WorkflowStatusNotificationGroups` ID -1 is a sentinel row, but its `WorkflowStatusGuid` does not match an exported `WorkflowStatus.Guid`. The cleanup script aligns it to the sentinel workflow status GUID `00000000-0000-0000-0000-000000000000` rather than deleting it.
- Hidden `WorkflowStatusNotificationGroups` ID 57 is removed.

## Active duplicate status names currently present

|Normalised name|Active records|IDs|
|---|---|---|
|declined|3:708c00e6-f45f-4cb2-8e91-a80b8b8e802e, 37:b9ba4510-6358-4c0a-bba1-5feb33c54f84|3, 37|
|new|33:9e0a10c7-94a0-4e25-afb1-14240d906c12, 48:3dab4339-a1c0-4abe-860a-4915a6cf94b6|33, 48|
|quoting|29:b88f95c2-41c9-4cc6-ad9f-d9223c4e852a, 50:9a60f983-24ba-4733-907e-c5cce0b691cb|29, 50|
|ready to send|14:02a2237f-2ae7-4e05-926f-38e8b7d050a0, 52:5c9cd674-7520-44d2-9464-2a681f2f2ba4|14, 52|
|rejected|8:0a6a71f7-b39f-4213-997e-2b3a13b6144c, 53:85b522aa-134c-4e6c-884a-ff7264d7dd2e|8, 53|


## Impact assessment

Exported objects directly affected:

- `SCore.Workflow`
- `SCore.WorkflowStatus`
- `SCore.WorkflowTransition`
- `SCore.WorkflowStatusNotificationGroups`
- `SCore.DataObjectTransition`
- `SCore.WorkflowNotificationQueue`
- `SCore.WorkflowNotificationQueueErrorLog`
- `SCore.DataObjects`

Exported procedures/functions that reference workflow data and must be regression-tested:

- `SCore.DataObjectTransitionUpsert`
- `SCore.WorkflowGetNextStatus`
- `SCore.tvf_WF_AuthorisationQueue`
- `SCore.tvf_WorkflowStatusNotificationGroups`
- `SCore.tvf_WorkflowValidate`
- `SCore.tvf_WorkflowStatusValidate`
- `SCore.tvf_WorkflowTransitionValidate`
- `SCore.WorkflowStatusUpsert`
- `SCore.WorkflowTransitionUpsert`
- `SCore.WorkflowStatusNotificationGroupsUpsert`

Database-wide dependencies cannot be fully proven from the supplied export. Run `00_Discovery.sql` in the target database and review any additional modules/tables it reports before executing `02_Apply_WorkflowCleanup.sql`.

## Execution order

1. Run `00_Discovery.sql` and save the output.
2. Run `01_PreValidation.sql`; it must return no blocking failures.
3. Review `Workflow_Duplicate_Mapping.csv` and confirm the retained IDs/GUIDs are acceptable.
4. Run `02_Apply_WorkflowCleanup.sql` in DEV/QA first. The script is transaction-wrapped and validation-gated.
5. Run `03_PostValidation.sql`; all blocking checks must return zero.
6. Regression-test: FormHelper status updates, workflow dropdowns, quote ready-to-send validation, authorisation queue, notification groups, quote/enquiry/job status changes.
7. Promote through controlled CI/CD only.

## Rollback approach

The apply script creates persistent backup tables under `SCore` before changing data. Use `04_Rollback_From_Backup.sql` with the cleanup run GUID shown by the apply script to restore affected status references and deleted configuration rows. If the cleanup has been promoted to a higher environment, also keep a normal database backup/snapshot before execution.

## Known risks and decisions

- Status ID alignment is not attempted. Changing identity IDs directly would be unsafe; this pack migrates references to retained identity rows instead.
- GUID replacement is not attempted for retained rows. Retained GUIDs remain stable. Duplicate GUIDs are removed with their duplicate rows after references are migrated.
- `Ready to Send` retains ID 14/GUID `02A2237F-2AE7-4E05-926F-38E8B7D050A0` because the exported upsert procedure hard-codes that GUID.
- `Rejected` and `Ready to Send` retained rows are updated to support `ShowInEnquiries = 1` because their duplicate rows were providing enquiry visibility.
- If any unexported module, metadata row, or table stores removed IDs/GUIDs outside the known SCore relationships, `00_Discovery.sql` should reveal it and the cleanup should pause.
