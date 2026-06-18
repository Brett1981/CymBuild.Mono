SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create view [SJob].[JobPaymentStages_List]')
GO

CREATE VIEW [SJob].[JobPaymentStages_List]
       --WITH SCHEMABINDING
AS
SELECT	jps.Guid,
		jps.RowStatus,
		CASE WHEN jps.StagedDate IS NULL THEN j.Number ELSE j.Number + N' - ' + CONVERT(NVARCHAR(10), jps.StagedDate) END AS Name,
		j.Guid As JobGuid,
		j.ID As JobID,
		jps.AfterStageId,
		jps.StagedDate,
		jps.Value
FROM	SJob.JobPaymentStages jps
JOIN	SJob.Jobs j ON (j.ID = jps.JobId)
GO