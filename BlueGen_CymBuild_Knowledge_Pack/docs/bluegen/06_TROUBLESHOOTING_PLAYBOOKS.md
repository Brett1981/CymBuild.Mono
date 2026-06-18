# CymBuild Troubleshooting Playbooks

These playbooks are for BlueGen and developers when diagnosing issues.

## Workflow/status issue

1. Identify the entity GUID and entity type.
2. Check `SCore.DataObjects` has a row for the record.
3. Check the `EntityTypeId` is correct.
4. Check latest `SCore.DataObjectTransition` for current state.
5. Check `SCore.Workflow`, `SCore.WorkflowStatus`, and `SCore.WorkflowTransition`.
6. Check `SCore.WorkflowGetNextStatus` or equivalent dropdown source.
7. Do not directly update status.
8. Correct through transition logic or `SCore.DataObjectTransitionUpsert`.

## Grid missing/wrong column

1. Identify grid definition and grid view definition.
2. Check SQL source/entity query returns the column with the expected alias.
3. Check `SUserInterface.GridViewColumnDefinitions` has an active column row.
4. Check label/format/visibility metadata.
5. Check duplicate column metadata.
6. Check `RowStatus` filters.
7. Check metadata deployment status.
8. Check client cache/reload if metadata looks correct.

## Dropdown empty

1. Identify the entity property/dropdown definition.
2. Check dropdown source/entity query.
3. Check lookup rows are active.
4. Check parameter mapping/parent filters.
5. Check `RowStatus NOT IN (0,254)`.
6. Check FormHelper/API call.
7. Check whether the current user has permissions/security filters.

## DataObject missing

Symptoms may include broken workflow, missing status, failed integration, invisible actions, broken diagnostics, or failed automation.

1. Identify business table and record GUID.
2. Confirm matching `SCore.DataObjects` row exists.
3. Confirm `EntityTypeId` points to the correct entity type.
4. Check if initial transition is missing.
5. Fix through approved remediation/upsert procedure.
6. Add preventative insert/upsert logic to the creation path.

## Sage/integration failure

1. Identify source business record.
2. Check `SCore.DataObjects` exists.
3. Check `SCore.IntegrationOutbox` or relevant integration table.
4. Check idempotency key/duplicate prevention.
5. Check worker/service logs.
6. Check Sage diagnostic page.
7. Check batch/transaction status.
8. Decide whether existing failed messages require replay after code deployment.

## Invoice automation issue

1. Check invoice schedule header.
2. Check schedule type: monthly, percentage, activity/milestone.
3. Check schedule configuration rows.
4. Check trigger instance materialisation.
5. Check invoice automation run details.
6. Check invoice request header.
7. Check invoice request items.
8. Check RIBA stage attribution.
9. Check transaction/batch state.
10. Check fee drawdown function/view.

## Classification issue

1. Confirm fields exist on source entity: Quote, Job, or Client Project.
2. Confirm lookup values exist in `SCore.DataClassifications` and `SCore.SecurityClassifications`.
3. Confirm read view/query returns classification GUID/name.
4. Confirm upsert procedure accepts and persists values.
5. Confirm propagation path, for example Quote → Job → Client Project.
6. Confirm metadata exposes dropdowns correctly.

## Non-Telerik regression

1. Compare old and new page feature inventory.
2. Confirm FormHelper flow remains intact.
3. Check search/filter/sort/paging.
4. Check row actions and modals.
5. Check dropdowns and formats.
6. Check loading/empty/error states.
7. Check CSS consistency with `cymbuild-v2.css`.
8. Confirm no new Telerik dependency was introduced.
