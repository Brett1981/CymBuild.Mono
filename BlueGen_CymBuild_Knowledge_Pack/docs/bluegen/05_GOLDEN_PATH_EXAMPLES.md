# Golden Path Examples

These examples teach BlueGen the correct CymBuild implementation style.

## Example 1 — Add a field to an existing entity

### Correct route

```text
SQL schema → Read query/view/function → Upsert procedure → EF/API if required → Metadata manifest → UI renders dynamically
```

### Steps

1. Confirm the target table and column do not already exist.
2. Add an idempotent schema script.
3. Update the entity read object/query/view/function using explicit columns.
4. Update the upsert procedure with a nullable/default-compatible parameter where required.
5. Confirm whether EF/protobuf/FormHelper changes are needed.
6. Add or update `SCore.EntityProperties` metadata.
7. Add property group placement if field appears on forms.
8. Add label/translation metadata.
9. Add grid column metadata if required.
10. Deploy schema first, then validate/apply metadata.

### BlueGen must not

- Add the field only in Razor.
- Hard-code a control if metadata exists.
- Break existing records by making a new field required without migration/default handling.

## Example 2 — Add a dropdown field

### Correct route

```text
Lookup/source table or entity query → EntityProperty dropdown metadata → Read/upsert SQL → UI dynamic dropdown
```

### Steps

1. Identify the lookup/reference source.
2. Confirm active-row filter uses `RowStatus NOT IN (0,254)` where appropriate.
3. Add dropdown definition or entity query metadata.
4. Add entity property metadata to use the dropdown.
5. Confirm save passes stable `Guid` where possible, resolving to numeric ID in SQL/API.
6. Ensure the UI does not hard-code dropdown values.

## Example 3 — Add a grid column

### Correct route

```text
SQL data source → GridViewColumnDefinition → Dynamic grid render
```

### Steps

1. Identify the grid and grid view definition.
2. Identify its SQL source/entity query.
3. Add the column to the SQL source using an explicit alias.
4. Add `GridViewColumnDefinition` metadata.
5. Set title/label, order, width, format, visibility, sorting/filtering.
6. Validate metadata and check for duplicates.

## Example 4 — Add status/workflow behaviour

### Correct route

```text
WorkflowStatus/WorkflowTransition metadata → DataObjectTransitionUpsert → latest transition = current state
```

### Steps

1. Confirm the entity has `SCore.DataObjects` rows.
2. Confirm `EntityTypeId` is correct.
3. Add/adjust workflow status and transitions.
4. Use `SCore.DataObjectTransitionUpsert` to apply status.
5. Confirm status dropdowns/actions use workflow metadata.

### Never do this

```sql
UPDATE SomeEntity
SET StatusId = @NewStatusId;
```

## Example 5 — Add an integration event

### Correct route

```text
Business action → API/SQL determines event → IntegrationOutbox → Worker → External system → Diagnostics
```

### Steps

1. Identify the business event and source entity.
2. Confirm `SCore.DataObjects` exists.
3. Create an outbox row idempotently.
4. Use a stable idempotency key.
5. Let a worker/process handle external calls.
6. Store success/failure/retry diagnostics.
7. Provide read-only troubleshooting SQL.

## Example 6 — Convert Telerik UI to non-Telerik

### Correct route

```text
Existing page behaviour → Feature inventory → Non-Telerik/shared control replacement → FormHelper preserved → UX verification
```

### Steps

1. Inventory existing UI features.
2. Confirm data calls go through `FormHelper`.
3. Replace grid/dropdown/modal/search/filter controls with CymBuild-native/shared equivalents.
4. Preserve modals, buttons, row actions, filtering, sorting, formatting, paging, loading and empty states.
5. Keep business rules out of UI.
6. Compare with `DynamicBatchGridViewV2` and `SageInboundDiagnosticsV2` patterns.
