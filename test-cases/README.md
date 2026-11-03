# CymBuild test-case manifests

This directory defines the proposed reviewable contract between agent-assisted
test planning and deterministic test execution.

## Rules

- Each case is a JSON document conforming to
  `schema/cymbuild-test-case.schema.json`.
- IDs are stable and unique across the repository.
- Every expected result is traceable to inspected source or approved behaviour.
- Metadata references use source manifest paths and stable Guids/keys, never
  environment-specific numeric IDs.
- `LIVE` cases must use `none` or `read-only` data mode and must set
  `liveWriteAllowed` to `false`.
- Managed entity creation and workflow changes must declare their invariant
  requirements.
- `proposed` means planned, not passing. `implemented` requires a real test path.
- Generated files must be deterministic; unchanged inputs produce no diff.

## Suggested repository layout after adoption

```text
test-cases/
  schema/
  architecture/
  metadata/
  forms/
  grids/
  workflows/
  integrations/
  regressions/
  examples/
```

The final directories should follow the existing CymBuild test organisation
confirmed during repository inventory.

## Example

`examples/metadata-form-render.example.json` is synthetic and documents the
shape only. It does not refer to a real CymBuild screen or grant permission to
run against any environment.
