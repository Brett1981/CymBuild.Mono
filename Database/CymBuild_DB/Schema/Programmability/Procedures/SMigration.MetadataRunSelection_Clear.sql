SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_Clear]')
GO

CREATE PROCEDURE [SMigration].[MetadataRunSelection_Clear]
(
    @RunGuid UNIQUEIDENTIFIER,
    @SchemaName NVARCHAR(128) = N'',
    @TableName NVARCHAR(128) = N'',
    @DifferenceType NVARCHAR(30) = N''
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @SelectionsToClear TABLE
    (
        SelectionGuid UNIQUEIDENTIFIER NOT NULL PRIMARY KEY
    );

    INSERT INTO @SelectionsToClear
    (
        SelectionGuid
    )
    SELECT
        sel.Guid
    FROM SMigration.Metadata_RunSelections AS sel
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sel.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sel.RunGuid = @RunGuid
      AND sel.RowStatus NOT IN (0,254)
      AND (@SchemaName = N'' OR tr.SchemaName = @SchemaName)
      AND (@TableName = N'' OR tr.TableName = @TableName)
      AND (@DifferenceType = N'' OR sel.DifferenceType = @DifferenceType);

    DECLARE @SelectionGuid UNIQUEIDENTIFIER;

    DECLARE SelectionCursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            clearRows.SelectionGuid
        FROM @SelectionsToClear AS clearRows
        ORDER BY clearRows.SelectionGuid;

    OPEN SelectionCursor;
    FETCH NEXT FROM SelectionCursor INTO @SelectionGuid;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC SCore.DeleteDataObject
            @Guid = @SelectionGuid;

        FETCH NEXT FROM SelectionCursor INTO @SelectionGuid;
    END;

    CLOSE SelectionCursor;
    DEALLOCATE SelectionCursor;

    UPDATE sel
    SET
        sel.RowStatus = 254,
        sel.SelectedByUserId = ISNULL(SCore.GetCurrentUserId(), -1),
        sel.SelectedOnUtc = SYSUTCDATETIME()
    FROM SMigration.Metadata_RunSelections AS sel
    INNER JOIN @SelectionsToClear AS clearRows
        ON clearRows.SelectionGuid = sel.Guid
    WHERE sel.RowStatus NOT IN (0,254);

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'SelectionClear',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata migration run selection cleared.',
        @DetailsJson = N'{}';
END
GO
