SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO






CREATE PROCEDURE [SSop].[AssetsDelete] 
								@Guid UNIQUEIDENTIFIER 
AS
BEGIN
	-- Check if used on a Job
	IF (EXISTS
		(
			SELECT	1
			FROM	SJob.Jobs AS j
			JOIN	SJob.Assets AS a ON (a.ID = j.UprnID)
			WHERE	(j.RowStatus NOT IN (0, 254))
				AND (a.Guid = @Guid)
		)
	)
	BEGIN 
	   ;THROW 60000, N'You cannot delete an Asset that has been used on a Job.', 1
	END

	-- Check if used on an Enquiry
	IF (EXISTS
		(
			SELECT	1
			FROM	SSop.Enquiries AS e
			JOIN	SJob.Assets AS a ON (a.ID = e.PropertyId)
			WHERE	(e.RowStatus NOT IN (0, 254))
				AND (a.Guid = @Guid)
		)
	)
	BEGIN 
	   ;THROW 60000, N'You cannot delete an Asset that has been used on an Enquiry.', 1
	END


	EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier
	

	UPDATE	SJob.Assets
	SET		RowStatus = 254
	WHERE	(Guid = @Guid)

END;

GO