SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[RibaStageLookupForInvoiceScheduleDrawdownsGet]')
GO

CREATE PROCEDURE [SJob].[RibaStageLookupForInvoiceScheduleDrawdownsGet]
(
      @UserId INT
    , @InvoiceScheduleGuid UNIQUEIDENTIFIER = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
          rs.Guid
        , rs.Description AS [Name]
        , rs.Number AS SortOrder
    FROM SJob.RibaStages AS rs
    WHERE rs.RowStatus NOT IN (0, 254)
      AND EXISTS
      (
          SELECT 1
          FROM SCore.ObjectSecurityForUser_CanRead(rs.Guid, @UserId) AS oscr
      )
    ORDER BY
          rs.Number
        , rs.Description
        , rs.ID;
END
GO