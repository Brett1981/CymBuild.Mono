SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE PROCEDURE [SJob].[RibaStagesUpsert] 
								@Number INT,
								@Description NVARCHAR(500),
								@Guid UNIQUEIDENTIFIER OUT
AS
BEGIN
	DECLARE @IsInsert BIT
    EXEC SCore.UpsertDataObject @Guid = @Guid,					-- uniqueidentifier
							@SchemeName = N'SJob',				-- nvarchar(255)
							@ObjectName = N'RibaStages',				-- nvarchar(255)
							@IsInsert = @IsInsert OUTPUT	-- bit

    IF (@IsInsert = 1)
    BEGIN
		INSERT	SJob.RibaStages
			 (RowStatus,
			  Guid,
			  Number,
			  Description
			)
		VALUES
			 (
				 1,						-- RowStatus - tinyint
				 @Guid,				-- Guid - uniqueidentifier
				 @Number,
				 @Description
			 );
	END;
	ELSE
	BEGIN
		UPDATE	SJob.RibaStages
		SET		Number = @Number,
				Description = @Description
		WHERE	(Guid = @Guid);
	END;
END;

GO