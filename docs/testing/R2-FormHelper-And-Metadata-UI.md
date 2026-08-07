# R2 FormHelper and metadata-driven UI tests

## Purpose

R2 adds fast contract and component coverage for the client and UI layers while preserving the mandatory CymBuild flow:

```text
Blazor PWA -> FormHelper/API.Client -> gRPC API -> EF -> SQL Server
```

No production code, Razor, SQL, metadata, workflow, DataObjects, outbox, or external integration behaviour is changed.

## Concursus.API.Client.Tests

The project uses a controlled `Grpc.Core.CallInvoker` to execute generated gRPC clients without network access. Tests verify:

- address-search and address-resolution validation, trimming, defaults, and request mapping;
- Universal Search current-user fallback, explicit-user preservation, and safe error replies;
- document navigation and resolution validation, request mapping, and API error propagation;
- AI Assistant upload-purpose and processing-status normalisation;
- deterministic `ClientFunctions` GUID, filename, date-window, and state-reset behaviour.

These tests exercise FormHelper as the client boundary. They do not call API services directly from UI code.

## Concursus.Components.Shared.Tests

The project uses bUnit for rendered component tests and direct unit tests for metadata helpers. Coverage includes:

- page title, section ordering, hidden groups, ungrouped fields, and field-type selection in `ViewDefinitionBuilder`;
- dropdown-definition configuration derived from EntityProperty metadata;
- one-load-per-definition behaviour, shared options, cancellation, and failure isolation in `V2DropdownLoader`;
- empty states, ordered sections, hidden fields, read-only values, required hints, and help text in `V2FormRenderer`;
- missing-property creation, dropdown options/current values, and validation messages in `V2FieldEditor`.

## Deliberate exclusions

R2 does not add browser automation, Telerik grid interaction, live MSAL, live gRPC, SQL Server, or external service tests. `FilteredDynamicGridViewV2` and token-expiry redirect behaviour remain for later PWA/component tranches after their dependencies are isolated into stable test seams.

## Acceptance criteria

R2 is accepted when:

1. the root solution builds in Release configuration;
2. the fast runner discovers seven test projects;
3. all seven projects pass;
4. each project produces a TRX file and Cobertura attachment;
5. the generated baseline reports seven test projects;
6. no production or deployment-target file changes.


## Test framework imports

Both R2 test projects include an explicit `global using Xunit;` import so xUnit attributes and assertions compile independently of SDK implicit usings.
## Generated gRPC client contract

The FormHelper test factory constructs the generated client using the fully qualified type `Concursus.API.Core.Core.CoreClient`, matching the production FormHelper constructor exactly. The installer validates both contracts before restore and build so namespace/service-name assumptions cannot silently drift.

