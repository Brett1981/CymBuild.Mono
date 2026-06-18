# **CymBuild — Metadata-Driven Application Platform**

*A high-level architecture guide for new developers*

---

## **1. The Big Picture**

CymBuild is a **metadata-driven business application platform** built around a strict layered architecture.

The platform supports Jobs, Enquiries, Quotes, Invoice Schedules, Finance, Sage integration, SharePoint/Outlook filing, workflow, dashboards, classifications, and dynamic metadata-driven UI.

The core principle is:

> **The UI does not own business logic.
> The UI renders metadata and sends user actions through FormHelper.
> Business rules and persistence flow through the API, EF, and SQL.**

### **Mandatory Runtime Flow**

All application behaviour must follow this flow:

```text
UI → FormHelper → gRPC API → EF → SQL
```

The Blazor UI must **not** call the API directly and must not contain business logic that belongs in the API, EF, or SQL layer.

### **Metadata-Driven UI Flow**

For metadata rendering, the platform uses this conceptual flow:

```text
SQL metadata → EF → gRPC API → FormHelper → Blazor PWA → Rendered UI
```

The database contains the metadata definitions. EF reads and builds rich metadata models. The API exposes those models through gRPC. The PWA renders forms, grids, tabs, dropdowns, actions, widgets, and layouts dynamically.

### **What Lives Where?**

#### **SQL**

SQL is the deployment target for:

* Business data:

  * Jobs
  * Enquiries
  * Quotes
  * Quote Items
  * Invoice Schedules
  * Invoice Requests
  * Transactions
  * RIBA Stages
  * Data/Security Classifications
  * Sage inbound/outbound integration records

* Runtime platform data:

  * `SCore.DataObjects`
  * `SCore.DataObjectTransition`
  * Workflow definitions
  * Workflow statuses
  * Workflow transitions

* UI metadata:

  * Entity types
  * Entity properties
  * Property groups
  * Grid definitions
  * Grid view definitions
  * Grid view columns
  * Dropdown definitions
  * Labels
  * Action menus
  * Widget definitions

SQL must always be written using explicit columns. Avoid `SELECT *`. Active-row filtering must normally use:

```sql
RowStatus NOT IN (0, 254)
```

#### **Concursus.EF**

Responsible for reading SQL and assembling runtime objects such as:

* `EntityType`
* `EntityProperty`
* `EntityPropertyGroup`
* `GridViewDefinition`
* `GridViewColumnDefinition`
* `DropDownListDefinition`
* `DataObject`
* Workflow and status-related models

#### **Concursus.API**

The gRPC API layer exposes EF-backed models and operations through services such as:

* `CoreService`
* `UiService`
* Domain-specific services where required

The API is responsible for mapping EF models to protobuf models, enforcing server-side rules, handling identity/security context, and coordinating persistence.

#### **Concursus.API.Client**

Contains the PWA’s API wrapper, primarily through `FormHelper`.

The PWA must call `FormHelper`, not construct direct gRPC clients.

#### **Concursus.PWA**

The Blazor PWA dynamically renders the UI using metadata retrieved through `FormHelper`.

It contains:

* Dynamic edit pages
* Dynamic grids
* Dashboard/widget rendering
* Shared layout handling
* Client-side validation display
* User interaction handling

It should not hard-code behaviour where metadata already exists.

#### **Concursus.Components.Shared**

Contains reusable controls and shared UI building blocks used by the PWA and related client surfaces.

This area is increasingly important as CymBuild moves away from Telerik controls.

---

## **2. Current Platform Direction**

## **2.1 Non-Telerik UI Progression**

CymBuild is progressing towards **non-Telerik UI controls** for new and modernised pages.

The direction is:

* Avoid Telerik for new work unless explicitly requested.
* Preserve existing functionality during conversion.
* Replace Telerik controls with CymBuild-native equivalents.
* Use shared reusable controls where possible.
* Preserve:

  * Modals
  * Buttons
  * Search
  * Filtering
  * Dropdowns
  * Formatting
  * Paging
  * Sorting
  * Row actions
  * Layout behaviour
  * Empty states
  * Loading states
  * Error handling

Current non-Telerik reference patterns include:

* `DynamicBatchGridViewV2`
* `SageInboundDiagnosticsV2`
* CymBuild modal services and modal host components
* CymBuild-native windowed modal patterns
* `cymbuild-v2.css` styling direction

Where a file or component is marked `V2`, treat it as the newer non-Telerik direction. However, for current implementation work, use the existing non-V2 version unless the work is specifically part of Telerik removal or no non-V2 version exists.

### **Non-Telerik Conversion Rules**

When converting a page or grid:

1. Do not remove existing functionality.
2. Do not move business logic into the UI.
3. Preserve the existing user journey.
4. Replace Telerik controls with equivalent shared/native controls.
5. Use metadata where metadata already exists.
6. Do not hard-code dropdowns, labels, columns, or actions if they are metadata-driven.
7. Keep the route:

```text
UI → FormHelper → gRPC API → EF → SQL
```

---

## **2.2 Code-First Metadata and Deployment Direction**

CymBuild is moving to a source-controlled, CI/CD-friendly metadata deployment model.

### **Core Principle**

```text
Schema = source-controlled SQL
Metadata = source-controlled manifests
Database = deployment target only
```

The database should not be treated as the source of truth for metadata authoring.

### **Metadata Deployment Flow**

Recommended deployment order:

```text
Schema deploy
→ Metadata validate
→ Metadata apply
→ Runtime verification
```

Metadata apply must be idempotent and should match by stable identifiers such as `Guid`, not environment-specific numeric IDs.

### **Important Metadata Rules**

* No manual metadata edits in QA, UAT, or LIVE.
* No manual DB promotion.
* No duplicate metadata rows.
* Metadata should be validated before apply.
* Metadata apply should be idempotent.
* Use stable `Guid` values.
* Do not copy numeric IDs between environments.
* Apply grid metadata in a safe order:

```text
Grid → View → Columns
```

### **Metadata Areas**

Metadata deployment currently covers or is expected to cover areas such as:

* `SCore.LanguageLabels`
* `SCore.LanguageLabelTranslations`
* `SCore.EntityTypes`
* `SCore.EntityProperties`
* `SCore.EntityPropertyGroups`
* `SCore.EntityQueries`
* `SCore.EntityQueryParameters`
* `SUserInterface.GridDefinitions`
* `SUserInterface.GridViewDefinitions`
* `SUserInterface.GridViewColumnDefinitions`
* `SUserInterface.DropDownListDefinitions`
* `SUserInterface.Labels`
* Action menus
* Widgets

---

## **2.3 Environments**

CymBuild follows controlled environment promotion.

Typical flow:

```text
DEV → QA → UAT → LIVE
```

General rules:

* DEV is flexible.
* QA is controlled.
* UAT is controlled and business-facing.
* LIVE is restricted.
* No manual changes should be made directly in LIVE.
* Schema and metadata changes should be deployed through controlled scripts/pipelines.

UAT/Test environments may be refreshed from LIVE. For some data areas, especially Products, LIVE can be the source of truth for existing business-maintained records.

---

## **3. Project Overview**

---

## **3.1 Concursus.EF**

**Role:** Data access and metadata model builder.

Concursus.EF reads the SQL-backed schema and metadata and constructs the object models used by the API.

### **Key Components**

#### **Core.cs**

Contains core domain and runtime models, including:

* Jobs
* Enquiries
* Quotes
* DataObject assembly
* DataProperty handling
* Workflow/status-related runtime information

#### **UserInterface.cs**

Contains metadata models including:

* `EntityType`
* `EntityProperty`
* `EntityPropertyGroup`
* `GridDefinition`
* `GridViewDefinition`
* `GridViewColumnDefinition`
* `DropDownListDefinition`
* Action menu definitions
* Widget definitions

### **Common Schemas**

EF maps or interacts with schemas including:

* `SCore`
* `SJob`
* `SSop`
* `SFin`
* `SProd`
* `SUserInterface`
* `SIntegration`
* `SAi`
* Other module schemas as required

EF transforms metadata such as:

> “This field is required, belongs in group X, uses dropdown Y, and is visible on edit page Z”

into strong models consumed by the gRPC API.

---

## **3.2 Concursus.API**

**Role:** gRPC service layer between EF and the PWA.

### **Key Services**

#### **CoreService**

Responsible for operations such as:

* Loading `DataObject` records
* Saving `DataObject` records
* Executing entity queries
* Running lookups
* Handling workflow/status actions
* Usage tracking
* Integration-facing operations where applicable

#### **UiService**

Responsible for UI metadata such as:

* Entity type definitions
* Entity property definitions
* Entity property groups
* Grid definitions
* Grid view definitions
* Grid column definitions
* Dropdown definitions
* Widget definitions
* Labels and UI metadata

### **API Responsibilities**

The API layer is responsible for:

* Mapping EF models to protobuf models
* Applying server-side validation
* Applying security/identity context
* Coordinating business rules
* Calling EF/repositories
* Logging and telemetry
* Protecting the UI from direct SQL/API implementation detail

Business rules should normally be here, in EF/repository logic, or SQL stored procedures/functions — not in Razor components.

---

## **3.3 Concursus.API.Client — FormHelper**

**Role:** The PWA’s single entry point into gRPC/API functionality.

The PWA must not create direct gRPC clients for application operations. It should use `FormHelper`.

### **Examples**

```csharp
LoadDataObjectAsync(...)
SaveDataObjectAsync(...)
GetGridViewDefinitionAsync(...)
GetGridDataAsync(...)
GetEntityTypeDefinitionAsync(...)
GetPropertyGroupsAsync(...)
GetUsageReportAsync(...)
```

### **FormHelper Encapsulates**

* gRPC channel usage
* API client calls
* Authentication headers
* Error handling
* Common metadata formatting
* Shared request/response handling
* Client-side consistency

### **Rule**

Do this:

```text
Blazor component → FormHelper → gRPC API
```

Do not do this:

```text
Blazor component → direct gRPC client
```

---

## **3.4 Concursus.PWA**

**Role:** Dynamic front-end renderer.

The PWA should not need to know what a Job, Enquiry, Quote, Invoice Schedule, or Classification is in hard-coded form.

It asks for metadata and renders the UI based on that metadata.

### **Dynamic Forms**

Common components include:

* `EditPage.razor`
* `FlexPropertyGroups.razor`
* `ShoreInput.razor`
* Shared/native input controls
* Dynamic dropdown controls
* Modal host components

### **Dynamic Grids**

Common components include:

* `DynamicGrid.razor`
* `DynamicGridView.razor`
* Newer non-Telerik V2 grid patterns
* Shared grid controls for search/filter/sort/actions

Grid behaviour should be driven by `GridViewDefinition` and related metadata.

### **Dashboards and Widgets**

“My Dashboard” loads:

* User preference JSON
* Widget definitions
* Widget layout metadata
* User-specific saved state

### **Helpers**

The PWA also contains helpers/services for:

* Date/time formatting
* Toast notifications
* Error handling
* Offline queue behaviour
* Modal handling
* Layout and UI formatting

---

## **3.5 Concursus.Components.Shared**

**Role:** Shared reusable UI controls.

This library should be used for common controls and reusable UI patterns.

Examples include:

* Signature controls
* Dialogs
* Toasts
* Common inputs
* Modal/window components
* Future trackable controls such as:

  * `TrackableTextBox`
  * `TrackableDropDown`
  * `TrackableDatePicker`
  * `TrackableCheckBox`

As Telerik is removed, this shared library becomes the preferred location for reusable non-Telerik controls.

---

## **4. Core Runtime Concepts**

---

## **4.1 EntityType and EntityProperty**

`EntityType` defines the type of business object.

Examples:

* Job
* Enquiry
* Quote
* Quote Item
* Invoice Schedule
* Invoice Request
* Transaction
* Product
* RIBA Stage
* Data Classification
* Security Classification

`EntityProperty` defines fields for an entity.

It includes metadata such as:

* Field name
* Data type
* Required flag
* Read-only flag
* Hidden flag
* Length
* Precision
* UI control type
* Dropdown source
* Lookup source
* Sort order
* Group placement
* Validation hints

---

## **4.2 EntityPropertyGroup**

`EntityPropertyGroup` controls form layout.

Example groups:

* Header
* Client Details
* Project Details
* Property Details
* Key Dates
* Finance
* Classification
* Security
* Workflow

A group normally includes:

* Label
* Sort order
* Layout rules
* List of properties
* Column/row placement

Rendered dynamically by the PWA.

---

## **4.3 DataObject**

`DataObject` is the core runtime record wrapper.

It contains:

* Entity type
* Entity type ID
* Entity GUID
* Data properties
* Runtime tracking state
* Status/workflow context where applicable

### **Critical Rule**

Every entity record must have a corresponding `SCore.DataObjects` row at insert.

That row must include the correct `EntityTypeId`.

If a business entity is created without a `DataObjects` row, downstream behaviour can fail, including:

* Workflow
* Status transitions
* Dynamic UI behaviour
* Authorisation queues
* Notifications
* Integration processes
* Diagnostics
* Generic entity operations

---

## **4.4 DataObjectTransition and Current Status**

CymBuild status must not be updated directly on the entity table.

### **Rule**

Do not update status directly.

Use:

```sql
SCore.DataObjectTransitionUpsert
```

The current state is determined by the latest transition.

```text
Latest DataObjectTransition = Current State
```

This is important for:

* Workflow correctness
* Audit history
* Approval queues
* Authorisation logic
* Notifications
* UI status dropdowns
* Status-dependent actions

### **Do Not**

```sql
UPDATE SomeEntity
SET StatusId = ...
```

### **Do**

Use the platform workflow/status transition mechanism.

---

## **4.5 GridViewDefinition**

`GridViewDefinition` controls dynamic grid behaviour.

It includes:

* Columns
* Column order
* Widths
* Captions
* Hidden/shown fields
* Formatting
* Sort behaviour
* Filter behaviour
* Action behaviour
* Entity query source

Grid definitions should be metadata-driven wherever possible.

---

## **4.6 Dropdown Definitions**

Dropdowns should normally come from metadata, entity queries, or platform dropdown definitions.

Avoid hard-coded dropdown values in Razor unless there is no metadata route and the exception is agreed.

This applies to areas such as:

* Workflow statuses
* RIBA stages
* Data classifications
* Security classifications
* Products
* Organisation units
* Business units
* User groups
* Finance statuses

---

## **4.7 Widgets and UserPreferences**

The user dashboard layout is stored as JSON.

Example:

```json
{
  "MyWorkCSS": null,
  "ItemStates": [
    {
      "RowSpan": 1,
      "ColSpan": 6,
      "Order": 1,
      "Id": "..."
    },
    {
      "RowSpan": 1,
      "ColSpan": 6,
      "Order": 2,
      "Id": "..."
    }
  ]
}
```

Each item state can define:

* Widget ID
* Row span
* Column span
* Order
* Colour
* Expanded/collapsed state
* User-specific layout preferences

Widgets may load:

* Metadata-driven mini grids
* KPIs
* Analytics
* User work queues
* Workflow queues
* Integration diagnostics

---

## **5. Business and Platform Modules**

---

## **5.1 Workflow and Status**

Workflow is central to CymBuild.

It supports:

* Record status transitions
* Approval routes
* Authorisation queues
* User/group-based actions
* Workflow notifications
* Status-specific UI behaviour

### **Key Rules**

* Use `SCore.DataObjectTransitionUpsert`.
* Do not directly update status fields.
* Current status comes from the latest transition.
* Workflow actions must respect configured transitions.
* User/group permissions must be applied through workflow/security rules.
* “Super User” style overrides must be explicit and controlled.
* Do not bypass workflow in UI code.

---

## **5.2 User Groups and Access Roles**

User groups are used throughout CymBuild to support both security and user experience.

Examples include:

* Determining workflow actions a user can perform
* Controlling approval and authorisation routes
* Granting access to business functions
* Controlling visibility of records
* Controlling dashboards and reports
* Showing/hiding screens, tabs, grids, buttons, and page components
* Supporting business-specific operational processes

User groups may be used by:

* Workflow
* Metadata visibility rules
* Authorisation queues
* Reports
* Dashboards
* Integration processes
* UI actions

Security decisions must not be made only in the UI. The API/SQL layer must enforce important security rules.

---

## **5.3 Data and Security Classifications**

CymBuild now includes support for project-level classification metadata.

The current classification direction includes:

### **Data Classification**

Examples:

* Official
* Official Sensitive

### **Security Classification**

Examples:

* Defcon 660

These fields are used on project-related records such as:

* Quotes
* Jobs
* Client Projects

The intended behaviour is:

* Users select classification values on the appropriate project records.
* Quote classification values can flow through to Job and Client Project records.
* Classification fields are metadata-driven dropdowns.
* Existing records should continue to work.
* Future phases may use these classifications for access control, filtering, reporting, or integration behaviour.

### **Implementation Notes**

Classification records should be stored in controlled lookup/reference tables, such as:

* `SCore.DataClassifications`
* `SCore.SecurityClassifications`

Metadata should expose these as dropdown fields on the relevant entities.

---

## **5.4 Invoice Schedules and RIBA Stage Support**

CymBuild supports invoice schedules and automated invoice request generation.

Supported schedule types include:

* Monthly schedules
* Percentage schedules
* Activity/milestone-based schedules

Recent platform direction includes optional RIBA stage support for invoice schedule items.

### **RIBA Stage Behaviour**

Monthly and percentage invoice schedule configuration can support optional RIBA stage selection.

This allows:

* Invoice requests to carry RIBA stage context
* Invoice request items to be attributed to a RIBA stage
* Fee drawdown to be tracked by RIBA stage
* Reporting to show stage-level fee movement

### **Rules**

* RIBA stage is optional.
* Existing schedules must continue working unchanged.
* If no RIBA stage is selected, existing non-stage behaviour should remain.
* New schedule-generated invoice request items should preserve stage attribution where configured.
* Do not break milestone/activity invoice generation.

---

## **5.5 Job Fee Drawdown and RIBA Stage Fees**

CymBuild supports RIBA/stage-level fee tracking for jobs.

Key concepts include:

* Job RIBA stage fees
* Agreed fee
* Invoiced value
* Paid value
* Remaining value
* Quote item to job fee carry-through
* User-created/custom RIBA stages

The fee grid should show accurate stage-based movement and should only count transactions that are valid for fee drawdown.

Important considerations:

* Stage-level values must not rely on fixed hard-coded RIBA0–RIBA7 assumptions where user-created stages exist.
* Invoiced values should respect transaction state.
* Paid values should be based on valid allocations.
* Non-stage records require explicit handling because they do not automatically roll up to a stage.

---

## **5.6 Sage Integration**

CymBuild integrates with Sage for finance-related processing.

The platform includes diagnostics and processing around:

* Inbound Sage documents
* Outbound finance events
* Invoice requests
* Transactions
* Batch states
* Retry/idempotency handling
* Integration diagnostics screens

### **Integration Rules**

Integration work should use:

```text
SCore.IntegrationOutbox
```

or the relevant platform outbox/integration pattern.

### **Important Integration Principles**

* Integration messages must be idempotent.
* Do not create duplicate external effects.
* Failed messages should remain diagnosable.
* Existing failed messages may remain failed until corrected code or replay handling is deployed.
* Diagnostics pages should expose enough information to understand:

  * Source record
  * Target entity
  * Current state
  * Failure reason
  * Retry status
  * Related transition/status information

### **Sage UI Direction**

Sage diagnostic pages are part of the non-Telerik conversion direction.

Reference patterns include:

* `SageInboundDiagnosticsV2`
* Non-Telerik grid rendering
* CymBuild modal patterns
* Search/filter/action equivalents

---

## **5.7 Outlook and SharePoint Integration**

CymBuild includes Outlook add-in and SharePoint filing integration.

The Outlook add-in supports filing emails to CymBuild-linked SharePoint locations.

Key concepts include:

* Office JS compose/read integration
* Graph-based email access
* CymBuild search/select target
* Save to SharePoint through API
* Folder selection
* Incoming/outgoing email visibility
* Filing confirmation UI
* Optional publish prompts

### **Rules**

* Add-in UI should preserve existing filing behaviour.
* Filing should go through the API.
* SharePoint target resolution should remain server-controlled.
* UI should not hard-code business rules around folder permissions.
* Permissions are driven by business unit / group access and SharePoint configuration.

---

## **5.8 AI and Assistant Knowledge**

CymBuild is progressing towards AI-assisted help and internal knowledge search.

Potential and current AI-related areas include:

* Assistant knowledge search
* CymBuild help content
* Developer diagnostics
* User support guidance
* Workflow explanations
* Metadata-aware help
* SQL/procedure diagnostics
* Future contextual assistance in the PWA

AI features should be treated as assistive, not authoritative unless backed by controlled CymBuild knowledge sources.

AI-related SQL/API work should follow the same platform standards:

```text
UI → FormHelper → gRPC API → EF → SQL
```

No direct UI-to-database or UI-to-external-model shortcuts should be introduced.

---

## **6. Request Flow Examples**

---

## **6.1 Opening a Grid — Example: Jobs List**

1. Blazor page loads.
2. UI calls `FormHelper`.
3. `FormHelper` calls the gRPC API.
4. API loads grid metadata through EF.
5. EF reads SQL metadata.
6. API returns `GridViewDefinition`.
7. PWA renders the dynamic grid.
8. Grid requests data through `FormHelper`.
9. API/EF executes the configured SQL entity query or view/function.
10. Data appears with configured paging, sorting, filtering, and actions.

```text
UI → FormHelper → gRPC API → EF → SQL
```

---

## **6.2 Opening a Record — Example: Enquiry Edit Page**

1. User clicks a row or menu item.
2. Edit page asks `FormHelper` for entity metadata.
3. `FormHelper` calls gRPC API.
4. API loads:

   * Entity type
   * Entity properties
   * Property groups
   * Dropdown definitions
   * Related metadata
5. API loads the underlying `DataObject`.
6. PWA builds the edit context.
7. User edits fields.
8. UI displays validation feedback.
9. Save goes through `FormHelper`.
10. API applies validation/business rules.
11. EF/SQL persists the record.
12. SQL ensures correct entity/data object behaviour.
13. Updated object/status returns to the PWA.

---

## **6.3 Saving a New Record**

When a new business record is inserted:

1. Business table row is inserted.
2. A matching `SCore.DataObjects` row must be inserted.
3. The correct `EntityTypeId` must be assigned.
4. Initial workflow/status transition should be created where required.
5. Any integration outbox records should be created idempotently.
6. The saved object returns through EF/API/FormHelper to the UI.

Never create a business entity without the corresponding platform runtime row.

---

## **6.4 Changing Status**

Status changes must use workflow transition logic.

Correct flow:

```text
UI action
→ FormHelper
→ gRPC API
→ EF/repository
→ SCore.DataObjectTransitionUpsert
→ SQL transition history
→ latest transition becomes current state
```

Incorrect flow:

```text
UI action
→ direct status update
```

Do not update status directly on the entity table.

---

## **6.5 My Dashboard Load**

1. User navigates to My Dashboard.
2. PWA calls `FormHelper`.
3. API loads user preferences and widget metadata.
4. EF reads dashboard/widget metadata and saved JSON layout.
5. PWA renders widgets according to:

   * `RowSpan`
   * `ColSpan`
   * `Order`
   * Widget ID
   * User state

---

## **6.6 Sage Integration Processing**

A typical integration flow should follow this pattern:

1. CymBuild business action occurs.
2. Server-side logic determines whether integration is required.
3. An idempotent outbox/integration record is created.
4. Worker/process sends or processes the integration message.
5. Success/failure is logged.
6. Diagnostics page shows current state.
7. Retry/replay behaviour remains idempotent.

Integration should not depend on UI-only actions or direct client-side external calls.

---

## **7. SQL Development Standards**

SQL is a core part of CymBuild and must be production-ready.

### **General Rules**

* Use explicit columns.
* Do not use `SELECT *`.
* Use idempotent scripts.
* Use `CREATE OR ALTER` where appropriate.
* Use `RowStatus NOT IN (0, 254)` for active rows unless there is a specific reason not to.
* Avoid destructive changes.
* Do not assume missing schema.
* Ask for schema if it is not known.
* Preserve existing behaviour.
* Do not overwrite user-maintained data unless explicitly required.
* Avoid environment-specific numeric IDs.
* Prefer stable GUIDs for metadata and cross-environment deployment.

### **Insert Rules**

When inserting platform-managed business entities:

* Insert the business row.
* Insert the corresponding `SCore.DataObjects` row.
* Use the correct `EntityTypeId`.
* Create required initial status transition if workflow applies.
* Create integration outbox entries idempotently where required.

### **Status Rules**

* Never update status directly.
* Use `SCore.DataObjectTransitionUpsert`.
* Current state is latest transition.

### **Metadata Rules**

* No direct metadata DB edits in controlled environments.
* No manual promotion.
* Idempotent by `Guid`.
* Validate before apply.
* Apply in dependency order.

---

## **8. UI Development Standards**

### **Core Rules**

* No direct API calls from Razor components.
* Use `FormHelper`.
* No business logic in UI.
* No hard-coding if metadata exists.
* No Telerik for new UI unless specifically requested.
* Preserve existing functionality during refactors.
* Use shared controls and CymBuild-native components.
* Keep behaviour consistent across dynamic forms and grids.

### **Dynamic UI Rules**

The UI should render based on:

* Entity metadata
* Property metadata
* Grid metadata
* Dropdown metadata
* Label metadata
* Action metadata
* Widget metadata
* User preferences

### **Non-Telerik Replacement Checklist**

When replacing Telerik controls, confirm equivalent support for:

* Search
* Filtering
* Sorting
* Paging
* Buttons
* Row actions
* Dropdowns
* Modals
* Confirm dialogs
* Validation messages
* Loading states
* Empty states
* Formatting
* Accessibility
* Keyboard behaviour where applicable

---

## **9. Integration Development Standards**

Integration features must be safe, replayable, and diagnosable.

### **Rules**

* Use `SCore.IntegrationOutbox` or the relevant platform outbox pattern.
* Ensure idempotency.
* Do not create duplicate external actions.
* Store enough diagnostic information to investigate failures.
* Preserve retry behaviour.
* Do not hide failed messages.
* Do not treat a UI success message as integration completion unless the server-side integration state confirms it.

### **Examples**

Integration standards apply to:

* Sage inbound processing
* Sage outbound processing
* Invoice automation
* SharePoint filing
* Outlook publishing
* Future AI/background processing
* Workflow notifications
* SignalR notifications

---

## **10. Deployment Standards**

### **Deployment Order**

Recommended order:

```text
1. Schema deploy
2. Metadata validate
3. Metadata apply
4. Data/reference deployment where required
5. Worker/API/PWA deployment
6. Post-deploy diagnostics
```

### **Schema**

* Source-controlled SQL
* Idempotent
* Explicit columns
* Safe for target environment
* No destructive changes without approval

### **Metadata**

* Source-controlled manifests
* Validated before apply
* Applied idempotently
* Matched by `Guid`
* No duplicates
* No manual target editing

### **Environments**

#### **DEV**

* Flexible
* Used for build and test
* Safe for iterative changes

#### **QA**

* Controlled
* Used for structured validation

#### **UAT**

* Controlled
* Business-facing
* No casual/manual metadata edits

#### **LIVE**

* Restricted
* No manual DB fixes unless approved emergency process
* Deployment only through controlled route

---

## **11. Common CymBuild Areas for New Developers**

A new developer should become familiar with these areas:

### **Core Platform**

* `SCore.DataObjects`
* `SCore.DataObjectTransition`
* `SCore.EntityTypes`
* `SCore.EntityProperties`
* Workflow tables
* User/group tables
* Entity queries

### **UI Metadata**

* `SUserInterface.GridDefinitions`
* `SUserInterface.GridViewDefinitions`
* `SUserInterface.GridViewColumnDefinitions`
* `SUserInterface.DropDownListDefinitions`
* `SUserInterface.Labels`
* Action menu metadata
* Widget metadata

### **Business Modules**

* `SSop.Enquiries`
* `SSop.Quotes`
* `SSop.QuoteItems`
* `SJob.Jobs`
* `SJob.RibaStages`
* `SFin.InvoiceSchedules`
* `SFin.InvoiceRequests`
* `SFin.InvoiceRequestItems`
* `SFin.Transactions`
* `SProd.Products`

### **Integration**

* Sage inbound/outbound processing
* Integration outbox
* Invoice automation worker
* Outlook add-in
* SharePoint filing
* SignalR notifications

### **Current Strategic Work**

* Telerik removal / non-Telerik UI
* Metadata CI/CD
* Classification fields
* RIBA stage fee tracking
* Invoice schedule automation
* Sage diagnostics and idempotency
* AI-assisted knowledge/help tooling
* SignalR expansion

---

## **12. Developer Checklist**

Before making a change, ask:

### **Architecture**

* Does it follow `UI → FormHelper → gRPC API → EF → SQL`?
* Is any business logic accidentally being placed in the UI?
* Is the UI using metadata where metadata exists?

### **Data**

* Does the entity require a `SCore.DataObjects` row?
* Is the correct `EntityTypeId` used?
* Is status handled through `DataObjectTransitionUpsert`?
* Is the current state derived from the latest transition?

### **SQL**

* Is the script idempotent?
* Are columns explicit?
* Is `RowStatus NOT IN (0, 254)` used correctly?
* Does it avoid destructive changes?
* Does it avoid environment-specific IDs?

### **Metadata**

* Is metadata source-controlled?
* Is it applied by `Guid`?
* Are there duplicates?
* Is the order correct: grid, view, columns?
* Has validation been considered?

### **UI**

* Is Telerik avoided for new work?
* Are non-Telerik equivalents complete?
* Are modals, filters, buttons, dropdowns, and formatting preserved?
* Does it avoid hard-coding?
* Does it preserve existing behaviour?

### **Integration**

* Is the outbox pattern used?
* Is it idempotent?
* Can failures be diagnosed?
* Is retry behaviour safe?

### **Deployment**

* Is the change safe for QA/UAT/LIVE?
* Does it avoid manual DB promotion?
* Does it fit the controlled deployment process?

---

## **13. Summary**

CymBuild is a metadata-driven application platform built around dynamic UI rendering, controlled metadata, workflow, integration, and source-controlled deployment.

The most important rule for developers is the runtime flow:

```text
UI → FormHelper → gRPC API → EF → SQL
```

The most important platform rules are:

* Do not call the API directly from the UI.
* Do not put business logic in the UI.
* Use metadata instead of hard-coding.
* Every inserted entity must have a `SCore.DataObjects` row with the correct `EntityTypeId`.
* Never update status directly.
* Use `SCore.DataObjectTransitionUpsert`.
* Latest transition is the current state.
* Schema is source-controlled SQL.
* Metadata is source-controlled manifests.
* Database is the deployment target only.
* No manual metadata DB edits or manual promotion.
* Use idempotent SQL and metadata apply.
* Use outbox/idempotency for integrations.
* Preserve behaviour during non-Telerik conversion.

Understanding these principles allows developers to safely:

* Diagnose metadata issues
* Build and maintain dynamic forms
* Build and maintain dynamic grids
* Extend workflow/status behaviour
* Add new entity types
* Support Sage and SharePoint/Outlook integration
* Implement classifications and RIBA-stage features
* Progress CymBuild towards reusable non-Telerik UI
* Deploy safely through DEV, QA, UAT, and LIVE
