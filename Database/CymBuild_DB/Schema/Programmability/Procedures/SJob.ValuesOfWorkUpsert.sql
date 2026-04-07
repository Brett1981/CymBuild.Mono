SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SJob].[ValuesOfWorkUpsert] 
								@Name NVARCHAR(100),
								@SortOrder INT,
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'ValuesOfWork',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.ValuesOfWork
			 (RowStatus,
			  Guid,
			  Name,
			  SortOrder
			)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Name,
				 @SortOrder
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.ValuesOfWork
		SET		Name = @Name,
				SortOrder = @SortOrder
		WHERE	(Guid = @Guid);
	END;
END;

GO