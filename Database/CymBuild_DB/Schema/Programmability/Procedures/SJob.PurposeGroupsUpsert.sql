SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[PurposeGroupsUpsert] 
								@Name NVARCHAR(100),
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'PurpostGroups',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0, -- bit
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.PurposeGroups
			 (RowStatus,
			  Guid,
			  Name
			)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.PurposeGroups
		SET		Name = @Name
		WHERE	(Guid = @Guid);
	END;
END;

GO