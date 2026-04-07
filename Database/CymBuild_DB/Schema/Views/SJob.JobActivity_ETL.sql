SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create view [SJob].[JobActivity_ETL]')
GO


CREATE VIEW [SJob].[JobActivity_ETL]
      --WITH SCHEMABINDING
AS
SELECT
    a.ID,
    a.RowVersion,
    CONVERT(DATE, a.[Date]) AS [DATE],
    a.SurveyorID,
    j.SurveyorID AS LeadSurveyorID,
    j.Number AS JobNumber,
    a.Title,
    actT.Name AS ActivityType,
    j.ID AS JobId,

    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM SFin.InvoiceRequestItems AS iri
            WHERE iri.ActivityId = a.ID
              AND iri.RowStatus NOT IN (0,254)
        )
        THEN 1 ELSE 0
    END AS InvoiceRequested,

    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM SFin.TransactionDetails AS td
            WHERE td.ActivityID = a.ID
              AND td.RowStatus NOT IN (0,254)
        )
        THEN 1 ELSE 0
    END AS Invoiced,

    stat.IsCompleteStatus AS IsComplete,

    CASE
        WHEN stat.Name = N'Cancelled' THEN 1 ELSE 0
    END AS IsCancelled,

    CASE
        WHEN ISNULL(a.InvoicingValue, 0) <> 0 THEN a.InvoicingValue
        ELSE ISNULL(a.InvoicingQuantity, 0) * ISNULL(i.BillableRate, 0)
    END AS InvoicingValue

FROM SJob.Activities a
JOIN SJob.ActivityStatus stat
    ON stat.ID = a.ActivityStatusID
JOIN SJob.ActivityTypes actT
    ON actT.ID = a.ActivityTypeID
JOIN SJob.Jobs j
    ON j.ID = a.JobID
JOIN SCore.Identities i
    ON i.ID = a.SurveyorID
JOIN SJob.Assets p
    ON p.ID = j.UprnID

WHERE
    a.RowStatus   NOT IN (0,254)
    AND stat.RowStatus NOT IN (0,254)
    AND actT.RowStatus NOT IN (0,254)
    AND j.RowStatus   NOT IN (0,254)
    AND i.RowStatus   NOT IN (0,254)
    AND p.RowStatus   NOT IN (0,254);
GO