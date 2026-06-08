SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRegistry_Seed]')
GO

CREATE PROCEDURE [SMigration].[MetadataRegistry_Seed]
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @Registry TABLE
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        GuidColumnName SYSNAME NOT NULL,
        PrimaryKeyColumnName SYSNAME NOT NULL,
        ApplyOrder INT NOT NULL,
        IsEnabled BIT NOT NULL,
        IsDataObjectBacked BIT NOT NULL,
        IsRetirable BIT NOT NULL,
        IsEnvironmentSpecific BIT NOT NULL,
        NaturalKeyJson NVARCHAR(MAX) NOT NULL,
        ParentDependencyJson NVARCHAR(MAX) NOT NULL
    );

    INSERT INTO @Registry
    (
        Guid,
        SchemaName,
        TableName,
        GuidColumnName,
        PrimaryKeyColumnName,
        ApplyOrder,
        IsEnabled,
        IsDataObjectBacked,
        IsRetirable,
        IsEnvironmentSpecific,
        NaturalKeyJson,
        ParentDependencyJson
    )
    VALUES
    ('10000000-0000-0000-0000-000000000001', N'SCore', N'Languages', N'Guid', N'ID', 10, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000002', N'SCore', N'RowStatus', N'Guid', N'ID', 20, 0, 0, 0, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000003', N'SCore', N'EntityDataTypes', N'Guid', N'ID', 30, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000004', N'SCore', N'Groups', N'Guid', N'ID', 40, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000005', N'SCore', N'Markets', N'Guid', N'ID', 50, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000006', N'SCore', N'Sectors', N'Guid', N'ID', 60, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000007', N'SCore', N'NonActivityTypes', N'Guid', N'ID', 70, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000008', N'SCore', N'System', N'Guid', N'ID', 80, 1, 1, 0, 1, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000009', N'SCore', N'Versioning', N'Guid', N'ID', 90, 1, 1, 0, 1, N'["Name"]', N'[]'),

    ('10000000-0000-0000-0000-000000000020', N'SCore', N'LanguageLabels', N'Guid', N'ID', 100, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000021', N'SCore', N'LanguageLabelTranslations', N'Guid', N'ID', 110, 1, 1, 1, 0, N'["LanguageLabelId","LanguageId"]', N'[{"SchemaName":"SCore","TableName":"LanguageLabels"},{"SchemaName":"SCore","TableName":"Languages"}]'),

    ('10000000-0000-0000-0000-000000000030', N'SCore', N'EntityTypes', N'Guid', N'ID', 200, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000031', N'SCore', N'EntityHobts', N'Guid', N'ID', 210, 1, 1, 1, 0, N'["SchemaName","ObjectName"]', N'[{"SchemaName":"SCore","TableName":"EntityTypes"}]'),
    ('10000000-0000-0000-0000-000000000032', N'SCore', N'EntityPropertyGroups', N'Guid', N'ID', 220, 1, 1, 1, 0, N'["Name"]', N'[{"SchemaName":"SCore","TableName":"EntityTypes"}]'),
    ('10000000-0000-0000-0000-000000000033', N'SCore', N'EntityProperties', N'Guid', N'ID', 230, 1, 1, 1, 0, N'["EntityHoBTID","Name"]', N'[{"SchemaName":"SCore","TableName":"EntityHobts"},{"SchemaName":"SCore","TableName":"EntityDataTypes"},{"SchemaName":"SCore","TableName":"EntityPropertyGroups"}]'),
    ('10000000-0000-0000-0000-000000000034', N'SCore', N'EntityQueries', N'Guid', N'ID', 240, 1, 1, 1, 0, N'["EntityTypeID","Name"]', N'[{"SchemaName":"SCore","TableName":"EntityTypes"}]'),
    ('10000000-0000-0000-0000-000000000035', N'SCore', N'EntityQueryParameters', N'Guid', N'ID', 250, 1, 1, 1, 0, N'["EntityQueryID","Name"]', N'[{"SchemaName":"SCore","TableName":"EntityQueries"}]'),
    ('10000000-0000-0000-0000-000000000036', N'SCore', N'EntityPropertyActions', N'Guid', N'ID', 260, 1, 1, 1, 0, N'["EntityPropertyID","ActionName"]', N'[{"SchemaName":"SCore","TableName":"EntityProperties"}]'),
    ('10000000-0000-0000-0000-000000000037', N'SCore', N'EntityPropertyDependants', N'Guid', N'ID', 270, 1, 1, 1, 0, N'["EntityPropertyID","DependantEntityPropertyID"]', N'[{"SchemaName":"SCore","TableName":"EntityProperties"}]'),

    ('10000000-0000-0000-0000-000000000100', N'SUserInterface', N'Icons', N'Guid', N'ID', 300, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000101', N'SUserInterface', N'GridViewTypes', N'Guid', N'ID', 310, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000102', N'SUserInterface', N'MetricTypes', N'Guid', N'ID', 320, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000103', N'SUserInterface', N'WidgetTypes', N'Guid', N'ID', 330, 1, 1, 1, 0, N'["Name"]', N'[]'),

    ('10000000-0000-0000-0000-000000000120', N'SUserInterface', N'GridDefinitions', N'Guid', N'ID', 400, 1, 1, 1, 0, N'["Code"]', N'[{"SchemaName":"SCore","TableName":"EntityTypes"}]'),
    ('10000000-0000-0000-0000-000000000121', N'SUserInterface', N'GridViewDefinitions', N'Guid', N'ID', 410, 1, 1, 1, 0, N'["GridDefinitionId","Code"]', N'[{"SchemaName":"SUserInterface","TableName":"GridDefinitions"},{"SchemaName":"SCore","TableName":"LanguageLabels"},{"SchemaName":"SCore","TableName":"EntityTypes"},{"SchemaName":"SUserInterface","TableName":"Icons"},{"SchemaName":"SUserInterface","TableName":"GridViewTypes"}]'),
    ('10000000-0000-0000-0000-000000000122', N'SUserInterface', N'GridViewColumnDefinitions', N'Guid', N'ID', 420, 1, 1, 1, 0, N'["GridViewDefinitionId","Name"]', N'[{"SchemaName":"SUserInterface","TableName":"GridViewDefinitions"},{"SchemaName":"SCore","TableName":"LanguageLabels"}]'),
    ('10000000-0000-0000-0000-000000000123', N'SUserInterface', N'GridViewActions', N'Guid', N'ID', 430, 1, 1, 1, 0, N'["GridViewDefinitionId","Name"]', N'[{"SchemaName":"SUserInterface","TableName":"GridViewDefinitions"},{"SchemaName":"SCore","TableName":"LanguageLabels"},{"SchemaName":"SUserInterface","TableName":"Icons"}]'),
    ('10000000-0000-0000-0000-000000000124', N'SUserInterface', N'GridViewWidgetQueries', N'Guid', N'ID', 440, 1, 1, 1, 0, N'["GridViewDefinitionId","Name"]', N'[{"SchemaName":"SUserInterface","TableName":"GridViewDefinitions"}]'),

    ('10000000-0000-0000-0000-000000000130', N'SUserInterface', N'DropDownListDefinitions', N'Guid', N'ID', 500, 1, 1, 1, 0, N'["Code"]', N'[{"SchemaName":"SCore","TableName":"EntityTypes"}]'),
    ('10000000-0000-0000-0000-000000000131', N'SUserInterface', N'ActionMenuItems', N'Guid', N'ID', 510, 1, 1, 1, 0, N'["NavigationUrl"]', N'[{"SchemaName":"SCore","TableName":"LanguageLabels"},{"SchemaName":"SUserInterface","TableName":"Icons"}]'),
    ('10000000-0000-0000-0000-000000000132', N'SUserInterface', N'MainMenuItems', N'Guid', N'ID', 520, 1, 1, 1, 0, N'["NavigationUrl"]', N'[{"SchemaName":"SCore","TableName":"LanguageLabels"},{"SchemaName":"SUserInterface","TableName":"Icons"}]'),
    ('10000000-0000-0000-0000-000000000133', N'SUserInterface', N'PropertyGroupLayouts', N'Guid', N'ID', 530, 1, 1, 1, 0, N'["EntityPropertyGroupId"]', N'[{"SchemaName":"SCore","TableName":"EntityPropertyGroups"}]'),
    ('10000000-0000-0000-0000-000000000134', N'SUserInterface', N'WidgetDashboards', N'Guid', N'ID', 540, 1, 1, 1, 0, N'["Name"]', N'[]'),
    ('10000000-0000-0000-0000-000000000135', N'SUserInterface', N'WidgetDashboardWidgetTypes', N'Guid', N'ID', 550, 1, 1, 1, 0, N'["WidgetDashboardId","WidgetTypeId"]', N'[{"SchemaName":"SUserInterface","TableName":"WidgetDashboards"},{"SchemaName":"SUserInterface","TableName":"WidgetTypes"}]');

    BEGIN TRANSACTION;

    UPDATE target
    SET
        target.RowStatus = 1,
        target.GuidColumnName = source.GuidColumnName,
        target.PrimaryKeyColumnName = source.PrimaryKeyColumnName,
        target.ApplyOrder = source.ApplyOrder,
        target.IsEnabled = source.IsEnabled,
        target.IsDataObjectBacked = source.IsDataObjectBacked,
        target.IsRetirable = source.IsRetirable,
        target.IsEnvironmentSpecific = source.IsEnvironmentSpecific,
        target.NaturalKeyJson = source.NaturalKeyJson,
        target.ParentDependencyJson = source.ParentDependencyJson
    FROM SMigration.Metadata_TableRegistry AS target
    INNER JOIN @Registry AS source
        ON source.SchemaName = target.SchemaName
       AND source.TableName = target.TableName;

    INSERT INTO SMigration.Metadata_TableRegistry
    (
        Guid,
        RowStatus,
        SchemaName,
        TableName,
        GuidColumnName,
        PrimaryKeyColumnName,
        ApplyOrder,
        IsEnabled,
        IsDataObjectBacked,
        IsRetirable,
        IsEnvironmentSpecific,
        NaturalKeyJson,
        ParentDependencyJson,
        CreatedOnUtc
    )
    SELECT
        source.Guid,
        1,
        source.SchemaName,
        source.TableName,
        source.GuidColumnName,
        source.PrimaryKeyColumnName,
        source.ApplyOrder,
        source.IsEnabled,
        source.IsDataObjectBacked,
        source.IsRetirable,
        source.IsEnvironmentSpecific,
        source.NaturalKeyJson,
        source.ParentDependencyJson,
        SYSUTCDATETIME()
    FROM @Registry AS source
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_TableRegistry AS target
        WHERE target.SchemaName = source.SchemaName
          AND target.TableName = source.TableName
    );

    COMMIT TRANSACTION;
END;
GO