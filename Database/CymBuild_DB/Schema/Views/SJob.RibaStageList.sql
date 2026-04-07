SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW [SJob].[RibaStageList]
           --WITH SCHEMABINDING
AS
SELECT	rs.Guid,
		rs.RowStatus,
		rs.Number, 
		CASE WHEN rs.Number > -1 THEN CONVERT(NVARCHAR(500), rs.Number) + N' - ' + rs.Description ELSE N'' END AS Name
FROM	SJob.RibaStages rs
GO