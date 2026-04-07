SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SJob].[ActivityStatusUpsert] 
								@Name NVARCHAR(100),
								@Colour NVARCHAR(50),
								@SortOrder INT,
								@IsCompleteStatus BIT,
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'ActivityStatus',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.ActivityStatus
			 (RowStatus,
			  Guid,
			  Name,
			  SortOrder,
			  IsCompleteStatus,
			  Colour)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name,
				 @SortOrder,
				 @IsCompleteStatus,
				 @Colour
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.ActivityStatus
		SET		Name = @Name,
				SortOrder = @SortOrder,
				IsCompleteStatus = @IsCompleteStatus,
				Colour = @Colour
		WHERE	(Guid = @Guid);
	END;
END;

GO