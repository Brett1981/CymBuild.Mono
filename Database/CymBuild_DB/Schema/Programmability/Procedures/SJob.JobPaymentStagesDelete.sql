SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO




CREATE PROCEDURE [SJob].[JobPaymentStagesDelete]
(
    @Guid UNIQUEIDENTIFIER
)
AS 
BEGIN 
	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	
	
    UPDATE	jps
	SET		RowStatus = 254
	FROM	SJob.JobPaymentStages jps
	WHERE	(Guid = @Guid)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SFin.TransactionDetails t
					WHERE	(t.JobPaymentStageId = jps.Id)
						AND	(t.RowStatus NOT IN (0, 254))
				)
			)
END
GO