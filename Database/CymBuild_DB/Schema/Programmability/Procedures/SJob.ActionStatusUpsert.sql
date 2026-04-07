SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[ActionStatusUpsert] 
								@Name NVARCHAR(150),
								@IsActive BIT,
								@Colour NVARCHAR(50),
								@SortOrder INT,
								@IsCompleteStatus BIT,
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'ActionStatus',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.ActionStatus
			 (RowStatus,
			  Guid,
			  Name,
			  IsActive,
			  SortOrder,
			  IsCompleteStatus,
			  Colour)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name,
				 @IsActive,
				 @SortOrder,
				 @IsCompleteStatus,
				 @Colour
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.ActionStatus
		SET		Name = @Name,
				IsActive = @IsActive,
				SortOrder = @SortOrder,
				IsCompleteStatus = @IsCompleteStatus,
				Colour = @Colour
		WHERE	(Guid = @Guid);
	END;
END;

GO