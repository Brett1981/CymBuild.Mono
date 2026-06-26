SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE OR ALTER FUNCTION [SFin].[tvf_JobOverdueTransactions]
(
    @UserId     INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
AS
RETURN
    SELECT
        t.ID,
        t.RowStatus,
        t.RowVersion,
        t.Guid,
        ISNULL(CurrentStatus.Name, N'') AS Status,
        t.Date,
        t.Number,
        tt.Name AS Type,
        account.Name AS FinanceAccount,
        CONVERT(DECIMAL(19, 2), tc.Gross) AS Gross,
        CONVERT(DECIMAL(19, 2), tc.Net) AS Net,
        CONVERT(DECIMAL(19, 2), tc.Vat) AS Vat,
        CONVERT(DECIMAL(19, 2), tc.RealOutstanding) AS Outstanding,
        CONVERT(DATE, tc.DueDate) AS DueDate,
        DATEDIFF(DAY, CONVERT(DATE, tc.DueDate), CONVERT(DATE, GETDATE())) AS DaysOverdue,
        t.PurchaseOrderNumber,
        t.SageTransactionReference,
        ISNULL(surveyor.FullName, N'') AS Consultant
    FROM
        SFin.Transactions AS t
    JOIN
        SJob.Jobs AS j ON (j.ID = t.JobID)
    JOIN
        SFin.TransactionTypes AS tt ON (tt.ID = t.TransactionTypeID)
    JOIN
        SFin.TransactionCalculations AS tc ON (tc.ID = t.ID)
    JOIN
        SCrm.Accounts AS account ON (account.ID = t.AccountID)
    LEFT JOIN
        SCore.Identities AS surveyor ON (surveyor.ID = t.SurveyorUserId)
    OUTER APPLY
        (
            SELECT TOP (1)
                wfs.Name
            FROM
                SCore.DataObjectTransition AS dot
            JOIN
                SCore.WorkflowStatus AS wfs ON (wfs.ID = dot.StatusID)
            WHERE
                (dot.DataObjectGuid = t.Guid)
                AND (dot.RowStatus NOT IN (0, 254))
                AND (wfs.RowStatus NOT IN (0, 254))
            ORDER BY
                dot.DateTimeUTC DESC,
                dot.ID DESC
        ) AS CurrentStatus
    WHERE
        (j.Guid = @ParentGuid)
        AND (j.RowStatus NOT IN (0, 254))
        AND (t.RowStatus NOT IN (0, 254))
        AND (tt.RowStatus NOT IN (0, 254))
        AND (tt.IsBank = 0)
        AND (tc.RealOutstanding <> 0)
        AND (tc.DueDate < GETDATE())
        AND EXISTS
            (
                SELECT 1
                FROM SCore.ObjectSecurityForUser_CanRead(j.Guid, @UserId) AS oscrJob
            )
        AND EXISTS
            (
                SELECT 1
                FROM SCore.ObjectSecurityForUser_CanRead(t.Guid, @UserId) AS oscrTransaction
            );
GO
