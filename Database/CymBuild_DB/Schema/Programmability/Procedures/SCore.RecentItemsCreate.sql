SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[RecentItemsCreate]
(
    @UserGuid UNIQUEIDENTIFIER,
	@EntityTypeGuid UNIQUEIDENTIFIER,
	@RecordGuid UNIQUEIDENTIFIER,
    @Label NVARCHAR(100),
	@Datetime DATETIME2
)
AS
BEGIN
    DECLARE @UserId INT,
			@EntityTypeId INT

	SELECT	@UserId = ID
	FROM	SCore.Identities 
	WHERE	(guid = @UserGuid)

	SELECT	@EntityTypeId = ID
	FROM	SCore.EntityTypes
	WHERE	(Guid = @EntityTypeGuid)
		AND	(IsRootEntity = 1)

	IF (@@ROWCOUNT < 1)
	BEGIN 
		RETURN	
	END

	/* Check the history item will be valid */ 
	if (NOT EXISTS 
			(
				SELECT	1
				FROM	SCore.DataObjects do 
				WHERE	(do.EntityTypeId = @EntityTypeId)
					AND	(do.Guid = @RecordGuid)
			)
		)
	BEGIN 
		;THROW 60000, N'The record/entity type combination is invalid.', 1
	END

	/* Todo check we're not inserting the most recent item again. */
	IF (NOT EXISTS 
			(
				SELECT	1
				FROM	SCore.RecentItems ri
				WHERE	(ri.UserID = @UserId)
					AND	(ri.RecordGuid = @RecordGuid)
					AND	(NOT EXISTS
							(
								SELECT	1
								FROM SCore.RecentItems ri2
								WHERE	(ri2.UserID = ri.UserID)
									AND	(ri2.Datetime > ri.Datetime)
							)
						)
			)
	)
	BEGIN 
		INSERT	SCore.RecentItems
    		 (RowStatus, Guid, Datetime, UserID, EntityTypeID, RecordGuid, Label)
		VALUES
    		 (
    			 1,	-- RowStatus - tinyint
    			 NEWID(),	-- Guid - uniqueidentifier
    			 @Datetime,	-- Datetime - datetime2(7)
    			 @UserId,	-- UserID - int
    			 @EntityTypeId,	-- EntityTypeID - int
    			 @RecordGuid,	-- RecordGuid - uniqueidentifier
    			 @Label	-- Label - nvarchar(100)
    		 )
	END
END
GO