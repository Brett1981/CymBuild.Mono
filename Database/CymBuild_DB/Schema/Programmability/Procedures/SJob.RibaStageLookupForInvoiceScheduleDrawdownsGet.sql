SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SJob].[RibaStageLookupForInvoiceScheduleDrawdownsGet]')
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
        , rs.Number AS SortOrder
        ,CASE
            WHEN rs.Number BETWEEN 0 AND 7
                THEN N'Riba Stage ' + CONVERT(NVARCHAR(20), rs.Number) + N' - ' + rs.Description
            WHEN rs.Number > 7
                THEN N'Fee Stage ' + CONVERT(NVARCHAR(20), rs.Number) + N' - ' + rs.Description
            ELSE N''
        END AS Name
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