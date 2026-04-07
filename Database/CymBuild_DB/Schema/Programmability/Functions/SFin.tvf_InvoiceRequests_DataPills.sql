SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create function [SFin].[tvf_InvoiceRequests_DataPills]')
GO

CREATE FUNCTION [SFin].[tvf_InvoiceRequests_DataPills]
(
    @Guid               UNIQUEIDENTIFIER, -- InvoiceRequest Guid
    @FinanceAccountGuid UNIQUEIDENTIFIER
)
RETURNS @DataPills TABLE
(
    [ID]        [INT]        IDENTITY (1, 1) NOT NULL,
    [Label]     NVARCHAR(50) NOT NULL,
    [Class]     NVARCHAR(50) NOT NULL,
    [SortOrder] INT          NOT NULL
)
AS
BEGIN
    -------------------------------------------------------------------------
    -- 1) Finance Account On Credit Hold
    -------------------------------------------------------------------------
    IF EXISTS
    (
        SELECT 1
        FROM SCrm.Accounts Ac
        WHERE Ac.Guid = @FinanceAccountGuid
          AND Ac.AccountStatusID = 4
    )
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Credit Hold', N'bg-danger', 1);
    END

    -------------------------------------------------------------------------
    -- 2) InvoiceRequest-level pills (based on the current InvoiceRequest row)
    -------------------------------------------------------------------------

    -- Blocked when BlockedReason <> ''
    IF EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequests ir
        WHERE ir.Guid = @Guid
          AND ir.RowStatus NOT IN (0, 254)
          AND NULLIF(LTRIM(RTRIM(ir.BlockedReason)), N'') IS NOT NULL
    )
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Blocked', N'bg-warning', 2);
    END

    -- Reconciliation when ReconciliationRequired = 1
    IF EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequests ir
        WHERE ir.Guid = @Guid
          AND ir.RowStatus NOT IN (0, 254)
          AND ir.ReconciliationRequired = 1
    )
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Reconciliation', N'bg-info', 3);
    END

    -- Automated when IsAutomated = 1
    IF EXISTS
    (
        SELECT 1
        FROM SFin.InvoiceRequests ir
        WHERE ir.Guid = @Guid
          AND ir.RowStatus NOT IN (0, 254)
          AND ir.IsAutomated = 1
    )
    BEGIN
        INSERT @DataPills (Label, Class, SortOrder)
        VALUES (N'Automated', N'bg-primary', 4);
    END

    RETURN;
END;
GO