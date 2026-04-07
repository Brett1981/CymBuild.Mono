# **CymBuild — Metadata-Driven Application Platform**

_A high-level architecture guide for new developers_

* * *

## **1\. The Big Picture**

CymBuild is a **metadata-driven UI platform**.  
Instead of hard-coding forms, grids, and layouts, the system reads **metadata from SQL**, transforms it through EF & gRPC, and the Blazor PWA **renders the entire UI dynamically**.

### **High-Level Flow**

`SQL metadata → EF → gRPC → Blazor client → Rendered UI`

### **What Lives Where?**

-   **SQL**
    
    -   Business data: Jobs, Enquiries, Quotes, etc.
        
    -   UI metadata: fields, groups, grids, widgets, actions, layouts.
        
-   **Concursus.EF**
    
    -   Reads SQL metadata and constructs rich model objects:
        
        -   `EntityType`, `EntityProperty`
            
        -   `EntityPropertyGroup`
            
        -   `GridViewDefinition`
            
        -   Widget definitions
            
        -   `DataObject`
            
-   **Concursus.API (gRPC)**
    
    -   Exposes EF models via `CoreService` and `UiService`.
        
-   **Concursus.API.Client (FormHelper)**
    
    -   PWA’s wrapper around gRPC calls.
        
-   **Concursus.PWA**
    
    -   Dynamically renders:
        
        -   Forms (EditPage)
            
        -   Grids (DynamicGridView)
            
        -   Dashboards/widgets (My Dashboard)
            

For almost all “UI changes”, **you update SQL metadata**, not Razor pages.

* * *

## **2\. Project Overview**

### **2.1 Concursus.EF**

**Role:** Data Access + Metadata Builder

Responsible for reading SQL and assembling all runtime metadata.

#### Key Components

-   **Core.cs**  
    Domain models: Jobs, Enquiries, Quotes, and DataObject assembly.
    
-   **UserInterface.cs**  
    Metadata models:
    
    -   `EntityType` / `EntityProperty`
        
    -   `EntityPropertyGroup`
        
    -   Grid & column definitions
        
    -   Action menus
        
    -   Widget definitions
        

#### EF Maps These Schemas

-   `SCore`
    
-   `SJob`
    
-   `SSop`
    
-   `SUserInterface`
    
-   etc.
    

EF transforms metadata such as _“this field is required and in group X”_ into strong models consumed by the API.

* * *

### **2.2 Concursus.API**

**Role:** The glue between EF and the PWA (gRPC services)

#### Services

-   **CoreService**
    
    -   Load DataObjects
        
    -   Save DataObjects
        
    -   Execute lookups
        
    -   Usage tracking
        
-   **UiService**
    
    -   EntityType definitions
        
    -   Property groups
        
    -   Grid definitions
        
    -   Widget metadata
        

#### Responsibilities

-   Map EF models → Protobuf models
    
-   Security & identity
    
-   Validation & business rules
    
-   Logging & telemetry
    

* * *

### **2.3 Concursus.API.Client (FormHelper)**

**Role:** The PWA’s single entry point into the API.

The PWA **never directly creates a gRPC client**; everything runs through `FormHelper`.

#### Examples

`LoadDataObjectAsync(entityType, id) SaveDataObjectAsync(dataObject) GetGridViewDefinitionAsync(entity, filters) GetUsageReportAsync(dateRange)`

Encapsulates:

-   Channel creation
    
-   Error handling
    
-   Shared metadata formatting
    
-   Authentication headers
    

* * *

### **2.4 Concursus.PWA (Blazor WebAssembly)**

**Role:** Dynamic front-end renderer\*\*

The PWA doesn’t know what a “Job” or “Enquiry” is.  
It asks for metadata, then renders UI based on it.

#### Dynamic Forms

-   `EditPage.razor` — generic CRUD page.
    
-   `FlexPropertyGroups.razor` — renders EntityPropertyGroups.
    
-   `ShoreInput.razor` — renders proper control for each field type.
    

#### Dynamic Grids

-   `DynamicGrid.razor`
    
-   `DynamicGridView.razor`
    

Uses metadata from `GridViewDefinition`.

#### Dashboards & Widgets

-   “My Dashboard” components load user layout JSON and widget definitions.
    

#### Helpers

-   `UiFormattingHelper` — Timestamp & DateTime consistency.
    
-   Toast notifications
    
-   Offline queue
    
-   Error-handling & interceptor services
    

* * *

### **2.5 Concursus.Components.Shared**

**Role:** Reusable UI building blocks\*\*

Includes:

-   `SignatureControl.razor`
    
-   Dialogs & toasts
    
-   Common inputs
    
-   Trackable components (future):
    
    -   `TrackableTextBox`
        
    -   `TrackableDropDown`
        

* * *

## **3\. Core Concepts**

### **3.1 EntityType & EntityProperty**

Defines the structure of an entity.

**EntityType examples:**

-   Job
    
-   Enquiry
    
-   Quote
    
-   InvoiceSchedule
    

**EntityProperty includes:**

-   Field name (e.g. `ClientName`)
    
-   Data type (string, date, decimal)
    
-   Required / read-only / hidden flags
    
-   Length / precision
    
-   UI hints (control type, lookup source)
    

These are pulled from SQL metadata tables.

* * *

### **3.2 EntityPropertyGroup (Form Layout)**

Controls how fields are grouped on the form.

**Example groups:**

-   Header
    
-   Client Details
    
-   Property Details
    
-   Key Dates
    

A group includes:

-   Title (via language label)
    
-   Sort order
    
-   A list of properties with column/row ordering
    

Rendered dynamically by FlexPropertyGroups.

* * *

### **3.3 DataObject (Runtime Data)**

The core runtime record representation.

Contains:

-   EntityType
    
-   A list/dictionary of `DataProperty` entries
    
-   Tracking state (new, existing, dirty)
    

#### Load Flow

1.  PWA → FormHelper → API → EF → SQL
    
2.  EF returns a DataObject
    
3.  API maps to protobuf
    
4.  PWA binds into EditContext
    

#### Save Flow

1.  PWA → FormHelper → API
    
2.  API maps DataObject to EF entities
    
3.  EF writes to SQL
    
4.  PWA receives updated object / status
    

* * *

### **3.4 GridViewDefinition (Dynamic Grids)**

Defines how grids should appear and behave.

Includes:

-   Column order
    
-   Widths
    
-   Sorting / filtering
    
-   Hidden/shown fields
    
-   Formatting
    

Loaded via UiService, rendered by DynamicGridView.

* * *

### **3.5 Widgets & UserPreferences (My Dashboard)**

The user’s dashboard layout is stored as JSON:

`{   "MyWorkCSS": null,   "ItemStates": [     { "RowSpan": 1, "ColSpan": 6, "Order": 1, "Id": "..." },     { "RowSpan": 1, "ColSpan": 6, "Order": 2, "Id": "..." }   ] }`

Each ItemState:

-   `Id` → widget definition reference
    
-   `RowSpan` / `ColSpan` → grid layout
    
-   `Order` → display order
    
-   `Color` (optional)
    

Widgets may load:

-   Metadata (mini grids)
    
-   Analytics (usage dashboard)
    
-   Forms or KPIs
    

* * *

## **4\. Request Flow Examples**

* * *

### **4.1 Opening a Grid (e.g. Jobs List)**

1.  Blazor page loads.
    
2.  Calls `GetGridViewDefinitionAsync("Jobs")`.
    
3.  API loads metadata through EF.
    
4.  API returns GridViewDefinition.
    
5.  PWA renders DynamicGridView.
    
6.  Grid requests data:
    
    -   `GetGridDataAsync("Jobs", filter, sort, page)`
        
    -   CoreService → EF → SQL view (e.g. `SJob.JobsView`)
        
7.  Data appears with paging/sorting/filtering.
    

* * *

### **4.2 Opening a Record (Edit Page)**

1.  User clicks a row or menu item.
    
2.  EditPage loads metadata:
    
    -   `GetEntityTypeDefinitionAsync("Enquiry")`
        
    -   `GetPropertyGroupsAsync("Enquiry")`
        
3.  Loads the underlying record via `LoadDataObjectAsync`.
    
4.  PWA builds an EditContext around DataObject.
    
5.  User edits:
    
    -   Validation runs automatically (metadata + Blazor).
        
6.  Save:
    
    -   PWA → FormHelper → SaveDataObjectAsync
        
    -   EF writes to SQL
        
    -   API returns success → PWA updates UI
        

* * *

### **4.3 My Dashboard Load**

1.  User navigates to My Dashboard.
    
2.  PWA fetches:
    
    -   UserPreferences JSON
        
    -   Widget definitions referenced in each ItemState
        
3.  For each widget:
    
    -   Metadata or analytics load as required
        
4.  PWA renders the layout using RowSpan, ColSpan, Order
    

* * *

## **5\. Summary**

CymBuild is a fully metadata-driven platform where **UI behaviour, layout, forms, fields, grids, and dashboards** are controlled by **SQL metadata**, not hard-coded Razor pages. The system uses a clean pipeline:

`Database → EF → gRPC → FormHelper → Blazor PWA`

Understanding this pipeline allows developers to:

-   Diagnose metadata issues
    
-   Understand dynamic form/grid generation
    
-   Add new entity types with minimal code
    
-   Extend widgets, layouts, or dashboard features
    
-   Build new reusable components in the shared library