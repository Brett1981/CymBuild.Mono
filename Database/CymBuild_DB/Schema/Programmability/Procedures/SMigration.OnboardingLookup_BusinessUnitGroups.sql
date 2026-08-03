SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[OnboardingLookup_BusinessUnitGroups]')
GO

PRINT (N'Create procedure [SMigration].[OnboardingLookup_BusinessUnitGroups]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingLookup_BusinessUnitGroups]')
GO
PRINT (N'Create procedure [SMigration].[OnboardingLookup_BusinessUnitGroups]')
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
          AND g.Guid <> ''00000000-0000-0000-0000-000000000000''
          AND ISNULL(g.DirectoryId, N'''') <> N''''
          AND EXISTS
          (
              SELECT 1
              FROM ' + QUOTENAME(@SourceDatabase) + N'.SCore.OrganisationalUnits AS ou
              WHERE ou.ID > 0
                AND ou.RowStatus NOT IN (0,254)
                AND
                (
                    ou.DefaultSecurityGroupId = g.ID
                    OR ou.Name = g.Name
                )
          )
        ORDER BY g.Name;';

    EXEC sys.sp_executesql @sql;
END
GO