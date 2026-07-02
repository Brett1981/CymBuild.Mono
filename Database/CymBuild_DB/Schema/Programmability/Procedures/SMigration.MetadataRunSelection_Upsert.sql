SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_Upsert]')
GO

CREATE PROCEDURE [SMigration].[MetadataRunSelection_Upsert]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128),
    @TableName NVARCHAR(128),
    @SourceRowGuid UNIQUEIDENTIFIER,
    @DifferenceType NVARCHAR(30) = N'',
    @IsSelected BIT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RegistryGuid UNIQUEIDENTIFIER,
        @StagedDifferenceType NVARCHAR(30),
        @SelectionGuid UNIQUEIDENTIFIER;

    SELECT TOP (1)
        @RegistryGuid = tr.Guid,
        @StagedDifferenceType = sr.DifferenceType
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND tr.SchemaName = @SchemaName
      AND tr.TableName = @TableName
      AND sr.SourceRowGuid = @SourceRowGuid
      AND (@DifferenceType = N'' OR sr.DifferenceType = @DifferenceType);

    IF @RegistryGuid IS NULL
        THROW 52100, 'The selected metadata staged row was not found.', 1;

    IF @StagedDifferenceType NOT IN (N'Insert', N'Update') AND ISNULL(@IsSelected, 0) = 1
        THROW 52101, 'Only Insert and Update metadata rows can be selected for apply.', 1;

    SELECT TOP (1)
        @SelectionGuid = sel.Guid
    FROM SMigration.Metadata_RunSelections AS sel
    WHERE sel.RunGuid = @RunGuid
      AND sel.RegistryGuid = @RegistryGuid
      AND sel.SourceRowGuid = @SourceRowGuid;

    IF ISNULL(@IsSelected, 0) = 1
    BEGIN
        SET @SelectionGuid = ISNULL(@SelectionGuid, NEWID());

        EXEC SMigration.MetadataDataObject_Ensure
            @Guid = @SelectionGuid,
            @SchemeName = N'SMigration',
            @ObjectName = N'Metadata_RunSelections';

        IF EXISTS
        (
            SELECT 1
            FROM SMigration.Metadata_RunSelections AS sel
            WHERE sel.Guid = @SelectionGuid
        )
        BEGIN
            UPDATE SMigration.Metadata_RunSelections
            SET
                RowStatus = 1,
                DifferenceType = @StagedDifferenceType,
                SelectionSource = N'Manual',
                SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
                SelectedOnUtc = SYSUTCDATETIME()
            WHERE Guid = @SelectionGuid;
        END
        ELSE
        BEGIN
            INSERT INTO SMigration.Metadata_RunSelections
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                DifferenceType,
                SelectionSource,
                SelectedByUserId,
                SelectedOnUtc
            )
            SELECT
                @SelectionGuid,
                1,
                @RunGuid,
                @RegistryGuid,
                @SourceRowGuid,
                @StagedDifferenceType,
                N'Manual',
                ISNULL(SCore.GetCurrentUserId(), -1),
                SYSUTCDATETIME();
        END;
    END
    ELSE
    BEGIN
        IF @SelectionGuid IS NOT NULL
        BEGIN
            EXEC SCore.DeleteDataObject
                @Guid = @SelectionGuid;

            UPDATE SMigration.Metadata_RunSelections
            SET
                RowStatus = 254,
                SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
                SelectedOnUtc = SYSUTCDATETIME()
            WHERE Guid = @SelectionGuid
              AND RowStatus NOT IN (0,254);
        END;
    END;
END
GO
