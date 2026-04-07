SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[JobTypesDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
	
	DECLARE @JobTypeID INT;

	SELECT @JobTypeID = ID
	FROM SJob.JobTypes
	WHERE Guid = @Guid;

	-- Ensure we only delete the type if it is not utilized by any job.
	IF(NOT EXISTS
	(
		SELECT 1 
		FROM SJob.Jobs
		WHERE JobTypeID = @JobTypeID
	))
	BEGIN
		EXEC SCore.DeleteDataObject @Guid = @Guid	-- uniqueidentifier

		UPDATE	SJob.JobTypes
		SET		RowStatus = 254
		WHERE	(Guid = @Guid)
	END
	ELSE
    BEGIN
        THROW 6000, 'Cannot delete Job Type because it is in use by one or more jobs.', 1;
    END;
	
  END
GO