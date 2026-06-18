# CymBuild Deployment Runbooks

## Environment principles

```text
DEV = flexible
QA = controlled
UAT = controlled / business-facing
LIVE = restricted
```

## Standard deployment order

```text
1. Schema deploy
2. Metadata validate
3. Metadata apply
4. API/worker deployment
5. PWA deployment
6. Post-deploy diagnostics
```

## Schema deployment

- Use source-controlled SQL.
- Scripts must be idempotent.
- Use explicit columns.
- Avoid destructive changes.
- Do not assume schema if not inspected.
- Use `CREATE OR ALTER` where appropriate.

## Metadata deployment

- Use source-controlled manifests.
- Validate before apply.
- Apply idempotently by `Guid`.
- Do not copy numeric IDs.
- Do not manually edit target metadata.

## API/worker deployment

- Confirm background workers are compatible with deployed schema.
- Confirm app settings/feature toggles.
- Confirm Sage/integration workers are enabled only where intended.
- Confirm retry/idempotency behaviour.

## PWA deployment

- Confirm PWA version includes expected client/API contract changes.
- Confirm cached assets are refreshed where applicable.
- Confirm new CSS/control changes do not break existing UI.

## Post-deploy checks

- Smoke test login/navigation.
- Open dynamic grid and edit page.
- Verify metadata-controlled field/grid changes.
- Verify workflow/status dropdowns.
- Verify relevant integration diagnostics.
- Check worker logs.
- Check error logs.

## LIVE restrictions

- No manual metadata edits.
- No ad-hoc status updates.
- No destructive scripts.
- Emergency changes must be reviewed and documented.
