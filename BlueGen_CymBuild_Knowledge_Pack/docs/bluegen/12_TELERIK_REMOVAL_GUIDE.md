# Telerik Removal Guide

CymBuild is moving towards non-Telerik UI for new and modernised pages.

## Reference patterns in the supplied snapshot

- `apps/Concursus.PWA/Shared/DynamicBatchGridViewV2.razor`
- `apps/Concursus.PWA/Shared/DynamicBatchGridViewV2.razor.cs`
- `apps/Concursus.PWA/Shared/DynamicBatchGridViewV2.razor.css`
- `apps/Concursus.PWA/Shared/Diagnostics/SageInboundDiagnosticsV2.razor`
- Modal patterns involving CymBuild modal services/hosts where present
- `cymbuild-v2.css` styling direction where present

## Conversion principles

- Preserve existing functionality.
- Preserve user journey.
- Preserve data flow through `FormHelper`.
- Do not move business logic into UI.
- Do not hard-code metadata-backed behaviour.
- Use shared components where possible.
- Do not introduce new Telerik controls unless requested.

## Feature checklist

For every converted page/grid, confirm:

- Search preserved.
- Filtering preserved.
- Sorting preserved.
- Paging preserved.
- Buttons preserved.
- Row actions preserved.
- Dropdowns preserved.
- Modals/dialogs preserved.
- Validation messages preserved.
- Loading state preserved.
- Empty state preserved.
- Formatting preserved.
- Permissions/visibility preserved.
- FormHelper flow preserved.

## Suggested conversion process

1. Capture current page features.
2. Identify all Telerik controls.
3. Identify data calls and ensure they go through FormHelper.
4. Identify metadata-driven fields/grids/dropdowns.
5. Replace controls one area at a time.
6. Compare against V2/reference components.
7. Test against existing user flows.
8. Remove unused Telerik imports/usings only after confirming no behaviour loss.

## BlueGen warning

Do not assume `V2` files are always the current production route. In this project, `V2` often indicates future-scope non-Telerik work. Use V2 as a reference unless the task explicitly says to implement/convert to V2 or the V2 file is the only available version.
