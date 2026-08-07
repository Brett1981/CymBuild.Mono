# CymBuild Metadata Rules

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

CymBuild is metadata-driven, but the 26.3 migration mechanism is **not purely manifest-driven**.

## Source of truth and deployment model

```text
Schema authoring = source-controlled SQL
Metadata migration configuration = source-controlled SMigration SQL/code
Metadata manifests = ValidateOnly/governance inputs
Database = deployment target only
```

The main metadata migration process is run-based and aligned with OnBoarding:

```text
Create Run → Stage → Validate → Build Identity Map
→ Review / Ignore / Override → Select Records
→ Apply Preview → Apply Selected or All Valid → Audit
```

## 26.3 implementation

The process uses:

- `SMigration.Metadata_Run`
- `SMigration.Metadata_StagedRows`
- `SMigration.Metadata_ValidationIssues`
- `SMigration.Metadata_ApplyIdentityMap`
- `SMigration.Metadata_ExecutionLog`
- `SMigration.Metadata_TableRegistry`
- `SMigration.Metadata_RunSelections`
- `SMigration.MetadataStage_Run`
- `SMigration.MetadataValidate_Run`
- `SMigration.MetadataApplyIdentityMap_Build`
- `SMigration.MetadataRunSelection_Upsert`
- `SMigration.MetadataRunSelection_Clear`
- `SMigration.MetadataApplyPreview_Get`
- `SMigration.MetadataApply_Run`

The PWA follows `MetadataMigration.razor → FormHelper.MetadataMigration.cs → CoreService.MetadataMigration.cs → SMigration SQL`.

## Manifest role

The following remain important but are governance/ValidateOnly support rather than the full migration engine:

- `metadata-manifests/v1/families/grids/grids.json`
- `metadata-manifests/v1/policies/allowlist.grids.json`
- `apps/Concursus.Metadata.Tools`
- `libs/Concursus.EF/MetadataManifests/ValidateOnly`

Do not remove or ignore them, and do not claim that applying manifests alone is the production metadata migration process.

## Deployment order

```text
1. Deploy idempotent schema SQL
2. Create/stage metadata run
3. Validate staged metadata
4. Build and review identity map
5. Resolve by review, ignore, or explicit override
6. Save selected rows, or use all valid rows when no explicit selection is required
7. Review Apply Preview
8. Apply selected or all valid rows
9. Verify execution log and post-apply checks
```

## Dependency order

Grid metadata must be applied in this order:

```text
GridDefinition → GridViewDefinition → GridViewColumnDefinition
```

## Metadata object families

- `SCore.EntityTypes`
- `SCore.EntityProperties`
- `SCore.EntityPropertyGroups`
- `SCore.EntityQueries`
- `SCore.EntityQueryParameters`
- `SCore.LanguageLabels`
- `SCore.LanguageLabelTranslations`
- `SUserInterface.GridDefinitions`
- `SUserInterface.GridViewDefinitions`
- `SUserInterface.GridViewColumnDefinitions`
- `SUserInterface.DropDownListDefinitions`
- `SUserInterface.Labels`
- Widgets and action menus

## Apply and identity rules

- Resolve cross-environment identity by stable `Guid`, never copied numeric IDs.
- Apply idempotently and avoid duplicate active rows.
- Every metadata entity insert that participates in platform identity must create the corresponding `SCore.DataObjects` row in the same operation.
- Do not use insert-then-update identity correction.
- No direct metadata edits in controlled environments.
- Ignored records and identity-map overrides must be persisted and auditable.
- Apply Preview must represent the selected/default valid plan.
- Preserve existing behavior unless the approved change explicitly changes it.

## Choosing the implementation route

| Request | 26.3 route |
|---|---|
| Add grid column | SQL source + run-based metadata stage/validate/selection/apply; manifest validation where covered |
| Rename label | Language label/translation metadata through SMigration run |
| Add dropdown field | Schema/read/upsert + entity/dropdown metadata + run-based migration |
| Hide/show field | Entity property/group metadata unless server-side security/business rules are required |
| Add workflow action | Workflow metadata plus transition validation; status applied only through `DataObjectTransitionUpsert` |
| Add page-specific behavior | PWA only for presentation/orchestration; data and business rules remain behind FormHelper/API |
