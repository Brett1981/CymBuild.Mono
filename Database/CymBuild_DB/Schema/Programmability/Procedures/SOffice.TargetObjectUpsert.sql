SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SOffice].[TargetObjectUpsert]
	(	@EntityTypeGuid UNIQUEIDENTIFIER,
		@RecordGuid UNIQUEIDENTIFIER,
		@Number NVARCHAR(100),
		@Name NVARCHAR(250),
		@FilingLocation NVARCHAR(MAX)
	)
AS
BEGIN
	DECLARE @EntityTypeID				 INT,
			@ID bigint

	SELECT	@EntityTypeID = ID
	FROM	SOffice.EntityTypes
	WHERE	(Guid = @EntityTypeGuid);


	SELECT	@ID = ID
	FROM	SOffice.TargetObjects
	WHERE	(Guid = @RecordGuid);

	IF (@@ROWCOUNT = 0)
	BEGIN
		INSERT	SOffice.TargetObjects
			 (Guid, RowStatus, Name, Number, EntityTypeId, FilingLocation)
		VALUES
			 (
				 @RecordGuid,	-- Guid - uniqueidentifier
				 1,	-- RowStatus - tinyint
				 @Name,	-- Name - nvarchar(250)
				 @Number,	-- Number - bigint
				 @EntityTypeID,	-- EntityTypeId - int
				 ISNULL(@FilingLocation, N'')
			 )
	END
	ELSE
	BEGIN 
		UPDATE	SOffice.TargetObjects
		SET		Name = @Name,
				Number = @Number,
				FilingLocation = ISNULL(@FilingLocation, N'')
		WHERE	(ID = @ID)
	END	
END;
GO