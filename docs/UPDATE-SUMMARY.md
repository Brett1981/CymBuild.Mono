# README / BlueGen Knowledge Pack 26.3 Update Summary

Validated on 4 August 2026 against `CymBuild.Monorepo(8).zip`, the uploaded schema, and CYB361 R22–R27.

## Major corrections

- Updated the pack from the previous initial snapshot baseline to release 26.3.
- Replaced pure manifest-driven metadata claims with the current SMigration run-based process and retained manifests as ValidateOnly/governance support.
- Added the completed CYB-361/CYB-362 workbench and R27 external controlled runner model.
- Added the verified QA `DeploymentApplied` evidence for the six-object 26.3 run.
- Updated all active-row guidance to `RowStatus <> 0 AND RowStatus <> 254`.
- Removed `SELECT *` from diagnostic examples and corrected actual 26.3 column names (`DateTimeUTC`, `CreatedOnUtc`, `PayloadJson`, `ColumnOrder`, `GridViewDefinitionId`).
- Corrected the Sage boundary to `services/Sage200Microservice`; documented `SageAPI_TEMP_DISABLED` as inactive.
- Updated V2/non-Telerik guidance to prefer `V2FormRenderer`, `V2FieldEditor`, and `FilteredDynamicGridViewV2`.
- Added DataObjects atomic-insert and no insert-then-update rules.
- Updated repository and API/gRPC inventories from current source.
- Converted all three navigation schemas from fenced Markdown into valid YAML and added 26.3 schema/metadata migration routes.
- Regenerated `BlueGen_CymBuild_Knowledge_Pack.json` as version `26.3-r27`.

## Important caveat

Some `appsettings*.json` files in the supplied repository still contain older 26.1 version strings. They were outside this documentation ZIP and were not altered. Release packaging should reconcile runtime version configuration separately.
