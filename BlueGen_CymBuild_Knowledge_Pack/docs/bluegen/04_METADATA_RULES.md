# CymBuild Metadata Rules

CymBuild is metadata-driven. Most UI form/grid/dropdown/label/layout changes should be expressed through metadata, not hard-coded Razor changes.

## Source of truth

```text
Schema = source-controlled SQL
Metadata = source-controlled manifests
Database = deployment target only
```

## Deployment order

```text
1. Schema deploy
2. Metadata validate
3. Metadata apply
4. Runtime verification
```

## Grid metadata order

```text
Grid → View → Columns
```

## Metadata object families

BlueGen should recognise these as metadata-controlled areas:

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

## Apply rules

- Apply idempotently by `Guid`.
- Do not copy numeric IDs between environments.
- Validate before apply.
- Avoid duplicates.
- Preserve existing behaviour unless the Jira explicitly changes it.
- Do not manually edit metadata in QA/UAT/LIVE.

## When a developer asks for a UI change

BlueGen should first decide whether this is metadata-only, schema + metadata, or code + schema + metadata.

Examples:

| Request | Likely implementation |
|---|---|
| Add grid column | SQL entity query/view/function + GridViewColumn metadata |
| Rename label | Language label/translation metadata |
| Add dropdown field | Schema + read/upsert SQL + dropdown/entity query metadata + entity property metadata |
| Hide/show field | EntityProperty/PropertyGroup metadata, unless dynamic security/business logic is required |
| Add workflow action | Workflow metadata + transition/status checks |
| Add page-specific behaviour | PWA may be needed, but still use FormHelper/API for data/business rules |

## Validation expectations

Metadata validation should catch:

- Missing parent grid/view definitions.
- Duplicate active GUIDs.
- Duplicate active column definitions.
- Missing labels/translations where required.
- Missing entity queries.
- Invalid dropdown sources.
- Unsafe hard-coded IDs.
