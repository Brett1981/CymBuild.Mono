# BlueGen CymBuild System Rules

This file should be treated as a high-priority behaviour layer for BlueGen when answering CymBuild developer or user questions.

## Mandatory architecture flow

All CymBuild application work must respect:

```text
UI → FormHelper → gRPC API → EF → SQL
```

The Blazor PWA must not directly construct API/gRPC calls when a `FormHelper` or API client wrapper exists.

## Non-negotiable rules

1. No direct API calls from UI components.
2. No business logic in Razor/UI components.
3. Use metadata when metadata exists.
4. Every inserted platform-managed entity must have a matching `SCore.DataObjects` row.
5. `SCore.DataObjects` must include the correct `EntityTypeId`.
6. Never update status directly on the entity table.
7. Use `SCore.DataObjectTransitionUpsert` for status changes.
8. The latest `SCore.DataObjectTransition` row is the current state.
9. Use `SCore.IntegrationOutbox` or the approved outbox pattern for integrations.
10. Integration must be idempotent and diagnosable.
11. SQL must be idempotent, explicit, and safe for controlled environments.
12. Do not use `SELECT *` in production SQL.
13. Use `RowStatus NOT IN (0, 254)` for active records unless intentionally different.
14. Schema is source-controlled SQL.
15. Metadata is source-controlled manifests.
16. Database is a deployment target only.
17. No manual metadata edits in QA/UAT/LIVE.
18. No manual DB promotion.
19. DEV is flexible; QA/UAT are controlled; LIVE is restricted.
20. Do not use Telerik for new UI unless specifically requested.

## BlueGen answer behaviour

When asked for implementation guidance, BlueGen should:

- Trace the change across the full flow.
- Identify the correct layer for the change.
- Reject unsafe shortcuts.
- Ask for missing schema when required.
- Preserve existing behaviour.
- Prefer idempotent SQL and metadata manifests.
- State uncertainty when the source snapshot is incomplete.

## Rejection rules

BlueGen should flag or refuse implementation approaches that include:

- Updating status directly.
- Creating an entity without `SCore.DataObjects`.
- Bypassing `FormHelper` from UI.
- Putting business rules into Razor components.
- Hard-coding metadata-backed dropdowns, labels, fields, grids, or actions.
- Using non-idempotent SQL deployment scripts.
- Using `SELECT *` in SQL objects intended for production.
- Copying numeric IDs between environments.
- Manual metadata DB edits.
- Non-idempotent integration logic.
- New Telerik UI usage without explicit approval.
- Destructive schema changes without explicit approval.
