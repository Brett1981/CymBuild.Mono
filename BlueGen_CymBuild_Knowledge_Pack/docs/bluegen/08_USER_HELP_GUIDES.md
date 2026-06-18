# CymBuild User Help Guides

This file provides user-facing guide outlines for BlueGen. These should be reviewed by business users before publication.

## How to create an Enquiry

1. Open the Enquiries area.
2. Select the action to create a new Enquiry.
3. Complete required client/project/property details.
4. Save the record.
5. Check the status and available next actions.

### Common issues
- Missing required fields.
- User cannot see an action due to permissions/workflow.
- Dropdown empty due to missing setup or filtering.

## How to create a Quote

1. Open the relevant Enquiry.
2. Use the configured action to create or manage Quotes.
3. Add quote sections/items as required.
4. Confirm products, RIBA stages, values, and classifications.
5. Save and progress through workflow.

## How to revise a Quote

1. Open the Quote.
2. Use the revise action where available.
3. Confirm the new version/copy is created.
4. Review copied sections/items/status.
5. Continue through the workflow.

### Support note
If revise fails, developers should check `SSop.QuotesRevise`, `SCore.DataObjects`, and `SCore.DataObjectTransitionUpsert` usage.

## How to create a Job from a Quote

1. Ensure Quote is in the required workflow state.
2. Use the configured create-job action.
3. Confirm Quote Items are valid.
4. Confirm classification and RIBA-stage fee information.
5. Open the created Job and review details.

## How to use Invoice Schedules

1. Open the Job or Finance/Invoicing area.
2. Choose the schedule type: monthly, percentage, or activity/milestone.
3. Enter schedule configuration.
4. Optionally select RIBA stage where supported.
5. Save and allow automation to generate invoice requests when due.

## How to understand RIBA stage fees

The fee drawdown grid shows stage-level financial movement, including agreed, invoiced, paid, and remaining values. If a transaction or invoice item has no RIBA stage, it may not roll up to a stage-specific row unless a rule exists to map it.

## How to use Outlook filing

1. Open the Outlook add-in.
2. Search/select the CymBuild target record.
3. Choose the SharePoint folder where available.
4. Confirm incoming/outgoing details and folder path.
5. File/publish the email.

## How to understand classifications

Data Classification and Security Classification identify the sensitivity/security handling of project records. They may be shown on Quotes, Jobs, and Client Projects. Future phases may use them for access control and reporting.

## How to interpret Sage/invoice statuses

Sage and invoice automation may involve background processing. A UI action may create a request or queue an outbox item before the external Sage action completes. Use diagnostics when there is a failure or delay.
