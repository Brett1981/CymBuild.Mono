SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
PRINT (N'Create procedure [SJob].[RibaStagesUpsert]')
GO
CREATE PROCEDURE [SJob].[RibaStagesUpsert]
    @Number INT,
    @Description NVARCHAR(500),
    @Guid UNIQUEIDENTIFIER OUT,
	@IsCustomStage BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @IsInsert BIT;
    DECLARE @EntityTypeId INT;

    IF @Guid IS NULL
       OR @Guid = '00000000-0000-0000-0000-000000000000'
    BEGIN
        SET @Guid = NEWID();
    END;

    SELECT TOP (1)
        @EntityTypeId = eh.EntityTypeID
    FROM SCore.EntityHobts AS eh
    WHERE eh.RowStatus NOT IN (0, 254)
      AND eh.SchemaName = N'SJob'
      AND eh.ObjectName = N'RibaStages'
      AND eh.IsMainHoBT = 1
    ORDER BY eh.ID;

    IF @EntityTypeId IS NULL
    BEGIN
        ;THROW 51000, 'Cannot save RibaStage because no active main EntityHoBT exists for SJob.RibaStages.', 1;
    END;

    EXEC SCore.UpsertDataObject
        @Guid = @Guid,
        @SchemeName = N'SJob',
        @ObjectName = N'RibaStages',
        @IncludeDefaultSecurity = 1,
        @IsInsert = @IsInsert OUTPUT;

    IF @IsInsert = 1
    BEGIN
        INSERT INTO SJob.RibaStages
        (
            RowStatus,
            Guid,
            Number,
            Description,
			IsCustomStage
        )
        VALUES
        (
            1,
            @Guid,
            @Number,
            @Description,
			@IsCustomStage
        );
    END;
    ELSE
    BEGIN
        UPDATE SJob.RibaStages
        SET
            Number = @Number,
            Description = @Description,
			IsCustomStage = @IsCustomStage
        WHERE Guid = @Guid
          AND RowStatus NOT IN (0, 254);
    END;
END;
GO