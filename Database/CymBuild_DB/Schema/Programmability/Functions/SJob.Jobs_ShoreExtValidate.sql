SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SJob].[Jobs_ShoreExtValidate]
	(
		@Guid UNIQUEIDENTIFIER,
		@JobTypeGuid UNIQUEIDENTIFIER
	)
RETURNS @ValidationResult TABLE
	(
		ID INT IDENTITY(1, 1) NOT NULL,
		TargetGuid UNIQUEIDENTIFIER NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
		TargetType CHAR(1) NOT NULL DEFAULT (''),
		IsReadOnly BIT NOT NULL DEFAULT ((0)),
		IsHidden BIT NOT NULL DEFAULT ((0)),
		IsInvalid BIT NOT NULL DEFAULT ((0)),
		[IsInformationOnly] [BIT] NOT NULL DEFAULT((0)),
		Message NVARCHAR(2000) NOT NULL DEFAULT ('')
	)
AS
BEGIN
	DECLARE @OrganisationUnitID INT,
			@JobTypeID			INT,
			@EntityHoBTGuid		UNIQUEIDENTIFIER;

	SELECT	@JobTypeID = ID
	FROM	SJob.Jobs
	WHERE	(Guid = @JobTypeGuid);


	IF (NOT EXISTS
	 (
		 SELECT 1
		 FROM	SJob.Jobs	  AS j
		 JOIN	SJob.JobTypes AS jt ON (jt.ID = j.JobTypeID)
		 WHERE	(jt.Guid = @JobTypeGuid)
			AND (jt.Name = N'Party Wall')
			AND (j.Guid	 = @Guid)
	 )
	   )
	BEGIN
		SELECT	@EntityHoBTGuid = eh.Guid
		FROM	SCore.EntityHobtsV AS eh
		WHERE	(eh.SchemaName = N'SJob')
			AND (eh.ObjectName = N'Jobs_ShoreExt');

		INSERT	@ValidationResult
			 (TargetGuid, TargetType, IsReadOnly, IsHidden, IsInvalid, Message)
		VALUES
			 (
				 @EntityHoBTGuid,
				 N'H',
				 0,
				 1,
				 0,
				 N''
			 );
	END;

	RETURN;
END;

GO