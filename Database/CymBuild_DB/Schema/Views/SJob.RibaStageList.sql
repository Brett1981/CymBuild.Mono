SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SJob].[RibaStageList]')
GO
PRINT (N'Create view [SJob].[RibaStageList]')
GO
PRINT (N'Create view [SJob].[RibaStageList]')
GO


CREATE VIEW [SJob].[RibaStageList]
AS
SELECT
    rs.Guid,
    rs.RowStatus,
    rs.Number,
    CASE
        WHEN rs.Number BETWEEN 0 AND 7
            THEN N'Riba Stage ' + CONVERT(NVARCHAR(20), rs.Number) + N' - ' + rs.Description
        WHEN rs.Number > 7
            THEN N'Fee Stage ' + CONVERT(NVARCHAR(20), rs.Number) + N' - ' + rs.Description
        ELSE N''
    END AS Name
FROM SJob.RibaStages AS rs
WHERE rs.RowStatus NOT IN (0,254)

GO