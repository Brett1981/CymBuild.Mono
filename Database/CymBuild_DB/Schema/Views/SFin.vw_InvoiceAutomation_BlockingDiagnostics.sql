SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SFin].[vw_InvoiceAutomation_BlockingDiagnostics]')
GO
/*
Purpose of the diagnostic view

This view answers one question, deterministically:
“Why did automated invoicing not proceed for this Schedule × Job?”

It is:

* Read-only
* Phase-3-safe
* QuoteItem-driven
* Non-mutating
* Explains all current block reasons explicitly

Perfect for:

* QA validation
* Support investigations
* Admin dashboards
* “Why isn’t this invoicing?” tickets

select * from SFin.vw_InvoiceAutomation_BlockingDiagnostics

*/
CREATE VIEW [SFin].[vw_InvoiceAutomation_BlockingDiagnostics]
    --WITH SCHEMABINDING
AS
WITH ScheduleJobScope AS
(
    SELECT DISTINCT
        qi.ID                AS QuoteItemId,
        qi.Guid              AS QuoteItemGuid,
        qi.InvoicingSchedule AS InvoiceScheduleId,
        sch.Guid             AS InvoiceScheduleGuid,
        qi.CreatedJobId      AS JobId
    FROM SSop.QuoteItems qi
    JOIN SFin.InvoiceSchedules sch
        ON sch.ID = qi.InvoicingSchedule
    WHERE
        qi.RowStatus NOT IN (0,254)
        AND sch.RowStatus NOT IN (0,254)
        AND qi.CreatedJobId NOT IN (-1,0)
        AND qi.InvoicingSchedule NOT IN (-1,0)
),
BlockingResolution AS
(
    SELECT
        sjs.*,
        j.ManualInvoicingEnabled,
        a.ID                    AS FinanceAccountId,
        acs.IsHold              AS AccountIsOnHold,
        acs.Name                AS AccountStatusName,

        CASE
            WHEN ISNULL(j.ManualInvoicingEnabled,0) = 1 THEN 1
            WHEN ISNULL(acs.IsHold,0) = 1 THEN 1
            ELSE 0
        END AS IsBlocked,

        CASE
            WHEN ISNULL(j.ManualInvoicingEnabled,0) = 1 THEN N'MANUAL_JOB'
            WHEN ISNULL(acs.IsHold,0) = 1 THEN N'ACCOUNT_ON_HOLD'
            ELSE N'NONE'
        END AS BlockedReasonCode,

        CASE
            WHEN ISNULL(j.ManualInvoicingEnabled,0) = 1
                THEN N'Job is explicitly set to Manual Invoicing'
            WHEN ISNULL(acs.IsHold,0) = 1
                THEN N'Finance account is on hold'
            ELSE N'Not blocked'
        END AS BlockedReason,

        CASE
            WHEN ISNULL(j.ManualInvoicingEnabled,0) = 1 THEN N'Job'
            WHEN ISNULL(acs.IsHold,0) = 1 THEN N'Account'
            ELSE N'None'
        END AS BlockingSource
    FROM ScheduleJobScope sjs
    JOIN SJob.Jobs j
        ON j.ID = sjs.JobId
        AND j.RowStatus NOT IN (0,254)
    LEFT JOIN SCrm.Accounts a
        ON a.ID = j.FinanceAccountID
    LEFT JOIN SCrm.AccountStatus acs
        ON acs.ID = a.AccountStatusID
)
SELECT
    InvoiceScheduleId,
    InvoiceScheduleGuid,
    JobId,
    QuoteItemId,
    QuoteItemGuid,
    IsBlocked,
    BlockedReasonCode,
    BlockedReason,
    ManualInvoicingEnabled,
    AccountIsOnHold,
    FinanceAccountId,
    AccountStatusName,
    BlockingSource
FROM BlockingResolution;
GO