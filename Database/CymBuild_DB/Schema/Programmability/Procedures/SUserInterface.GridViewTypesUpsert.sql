SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SUserInterface].[GridViewTypesUpsert] 
								@Name NVARCHAR(50),
								@Guid   UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SUserInterface',				-- nvarchar(255)
							@ObjectName = N'GridViewTypes',				-- nvarchar(255)
							@IncludeDefaultSecurity = 0,
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SUserInterface.GridViewTypes
			 (RowStatus,
			  Guid,
			  Name
			  )
		VALUES
			 (
				 1,						
				 @Guid,				
				 @Name
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SUserInterface.GridViewTypes
		SET		Name = @Name
		WHERE	(Guid = @Guid);
	END;
END;

GO