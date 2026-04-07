SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[ActionPrioritiesUpsert] 
								@Name NVARCHAR(150),
								@IsActive BIT,
								@Colour NVARCHAR(50),
								@SortOrder INT,
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'ActionPriorities',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.ActionPriorities
			 (RowStatus,
			  Guid,
			  Name,
			  IsActive,
			  SortOrder,
			  Colour)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name,
				 @IsActive,
				 @SortOrder,
				 @Colour
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.ActionPriorities
		SET		Name = @Name,
				IsActive = @IsActive,
				SortOrder = @SortOrder,
				Colour = @Colour
		WHERE	(Guid = @Guid);
	END;
END;

GO