# CymBuild Glossary

## DataObject
Generic runtime representation of a CymBuild business record. Platform-managed entities must have a `SCore.DataObjects` row.

## EntityType
Metadata definition of a business/runtime object type, such as Job, Enquiry, Quote, Invoice Schedule, or Transaction.

## EntityProperty
Metadata definition of a field/property for an entity.

## EntityPropertyGroup
Metadata definition controlling how fields are grouped/rendered on dynamic forms.

## EntityQuery
Metadata-backed SQL query/source used for data loading, dropdowns, grids, or entity operations.

## GridDefinition
Top-level grid metadata definition.

## GridViewDefinition
Metadata definition of a specific view of a grid.

## GridViewColumnDefinition
Metadata definition of a column in a grid view.

## DropDownListDefinition
Metadata definition of a dropdown source and behaviour.

## DataObjectTransition
Workflow/status transition history for a DataObject.

## Current State
The latest active DataObject transition.

## WorkflowStatus
A configured status that an entity can occupy.

## WorkflowTransition
A configured allowed movement from one status to another.

## FormHelper
Client-side API wrapper used by the PWA to call backend services.

## RIBA Stage
Project stage used for fee attribution and reporting. CymBuild supports dynamic/user-created stages and should not assume only fixed RIBA0–RIBA7 stages.

## Invoice Schedule
Configuration that controls automated or scheduled invoice request generation.

## Invoice Request
A CymBuild finance request generated manually or automatically before becoming/creating transactions or Sage submissions.

## Transaction
Finance transaction used for invoicing/payment/batch/Sage flows.

## IntegrationOutbox
Outbox table/pattern used to queue external integration messages safely and idempotently.

## Data Classification
Business classification indicating data sensitivity, such as Official or Official Sensitive.

## Security Classification
Security handling classification, such as Defcon 660.

## Metadata Manifest
Source-controlled representation of metadata intended to be validated and applied through CI/CD.

## Telerik Removal
Current programme of replacing Telerik UI controls with CymBuild-native/non-Telerik shared controls while preserving existing behaviour.
