SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingLookup_BusinessUnitGroups]')
GO
CREATE PROCEDURE [SMigration].[OnboardingLookup_BusinessUnitGroups]
    @SourceDatabase SYSNAME
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @sql NVARCHAR(MAX) = N'
        SELECT
            Guid = CAST(g.Guid AS NVARCHAR(36)),
            Name = ISNULL(g.Name, N''''),
            Code = ISNULL(g.Code, N''''),
            Description = CONCAT(ISNULL(g.Code, N''''), N'' - '', ISNULL(g.Name, N''''))
        FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.Groups AS g
        WHERE g.RowStatus NOT IN (0,254)
          AND g.ID > 0
          AND ISNULL(g.DirectoryId, N'''') <> N''''
        ORDER BY g.Name;';

    EXEC sys.sp_executesql @sql;
END
GO