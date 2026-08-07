# Telerik Removal Guide

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

CymBuild 26.3 prefers non-Telerik/shared controls for new and modernized work. Existing Telerik assets still exist in the repository, so removal must be scoped and parity-tested rather than performed globally by assumption.

## Preferred 26.3 patterns

- `libs/Concursus.Components.Shared/Controls/V2FormRenderer.razor`
- `libs/Concursus.Components.Shared/Controls/V2FieldEditor.razor`
- `apps/Concursus.PWA/Shared/FilteredDynamicGridViewV2.razor`
- `apps/Concursus.PWA/Shared/DynamicBatchGridViewV2.razor`
- `apps/Concursus.PWA/Shared/Diagnostics/SageInboundDiagnosticsV2.razor`
- `libs/Concursus.Components.Shared/wwwroot/css/cymbuild-v2.css`
- CymBuild modal services/hosts and windowed modal patterns

## Rules

- No new Telerik usage unless explicitly requested.
- Preserve the mandatory `UI → FormHelper → gRPC → EF → SQL` path.
- Keep business logic and security enforcement out of UI.
- Use metadata for fields, grids, dropdowns, labels and actions where metadata exists.
- Prefer the V2 components above for current non-Telerik implementation; do not automatically revert to non-V2 simply because it is older.
- Preserve backward compatibility and every visible behavior.

## Parity checklist

Validate search, filtering, sorting, paging, total counts, export, column formatting, pills/status presentation, buttons, row actions, bulk operations, dropdowns, modals, confirmation, validation, loading, empty/error states, permissions, accessibility, responsive/mobile behavior, keyboard behavior and CSS isolation.

## Conversion process

1. Capture a feature and behavior inventory from the current route.
2. Trace every data call through FormHelper.
3. Identify metadata-owned behavior.
4. Convert one bounded surface at a time using V2/shared controls.
5. Run existing PWA/API tests and user-flow regression checks.
6. Remove Telerik imports/assets only when the scoped route has no remaining dependency and global consumers are unaffected.

`apps/Concursus.PWA/wwwroot/index.html` in the supplied source still references Telerik assets. Do not remove those global references as part of an unrelated page conversion. The architectural standard names `Concursus.Components.Shared.wwwroot.css.Cymbuild_ui.css` as the canonical stylesheet, while this snapshot currently contains `libs/Concursus.Components.Shared/wwwroot/css/cymbuild-v2.css`; treat this as a controlled source reconciliation, not a reason to duplicate styles.
