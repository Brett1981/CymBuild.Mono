SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SSop].[ContractsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	UPDATE	c
	SET		RowStatus = 254
	FROM	SSop.Contracts c
	WHERE	(Guid = @Guid)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SSop.Quotes q
					WHERE	(q.ContractID = c.ID)
						AND	(q.RowStatus NOT IN (0, 254))
				)
			)
		AND	(NOT EXISTS
				(
					SELECT	1
					FROM	SJob.Jobs j
					WHERE	(j.ContractID = c.ID)
						AND	(j.RowStatus NOT IN (0, 254))
				)
			)
END;

GO