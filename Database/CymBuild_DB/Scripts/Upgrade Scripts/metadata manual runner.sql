USE [CymBuild_QA];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE
    @RunGuid UNIQUEIDENTIFIER,
    @ForceApply BIT = 0;

EXEC SMigration.MetadataRegistry_Seed;

EXEC SMigration.MetadataRun_Create
    @SourceEnvironment = N'DEV',
    @TargetEnvironment = N'QA',
    @SourceServerName = N'SOC-SQLDEVBRE01\GENERAL',
    @SourceDatabaseName = N'CymBuild_Dev',
    @TargetServerName = N'SOC-SQLDEVBRE01\GENERAL',
    @TargetDatabaseName = N'CymBuild_QA',
    @IsValidateOnly = 0,
    @RunGuid = @RunGuid OUTPUT;

EXEC SMigration.MetadataStage_Run @RunGuid = @RunGuid;
EXEC SMigration.MetadataValidate_Run @RunGuid = @RunGuid;

SELECT *
FROM SMigration.Metadata_ValidationIssues
WHERE RunGuid = @RunGuid
  AND RowStatus NOT IN (0,254)
ORDER BY Severity DESC, IssueCode;

EXEC SMigration.MetadataApplyIdentityMap_Build @RunGuid = @RunGuid;

EXEC SMigration.MetadataApply_Run
    @RunGuid = @RunGuid,
    @ForceApply = @ForceApply;

EXEC SMigration.MetadataRun_Get @RunGuid = @RunGuid;


    
--select * from SMigration.Metadata_TableRegistry

--UPDATE SMigration.Metadata_TableRegistry
--SET
--    IsEnabled = 0,
--    IsDataObjectBacked = 0,
--    IsRetirable = 0
--WHERE SchemaName = N'SCore'
--  AND TableName = N'RowStatus'
--  AND RowStatus NOT IN (0,254);

--    SELECT
--    COUNT_BIG(1) AS RegistryRows,
--    SUM(CASE WHEN RowStatus NOT IN (0,254) AND IsEnabled = 1 THEN 1 ELSE 0 END) AS EnabledRows
--FROM SMigration.Metadata_TableRegistry;

--SELECT
--    ID,
--    SchemaName,
--    TableName,
--    ApplyOrder,
--    IsEnabled,
--    RowStatus
--FROM SMigration.Metadata_TableRegistry
--ORDER BY ApplyOrder;

--EXEC SMigration.MetadataRegistry_Seed;

--SELECT *
--FROM SMigration.Metadata_Run
--WHERE Guid = '6B1E3E44-E503-4A25-8F43-79197D41A723';

--SELECT
--    IssueCode,
--    Severity,
--    COUNT(*) AS IssueCount
--FROM SMigration.Metadata_ValidationIssues
--WHERE RunGuid = '6B1E3E44-E503-4A25-8F43-79197D41A723'
--  AND RowStatus NOT IN (0,254)
--GROUP BY
--    IssueCode,
--    Severity
--ORDER BY
--    Severity,
--    IssueCode;

--SELECT
--    DifferenceType,
--    COUNT(*) AS [RowCount]
--FROM SMigration.Metadata_StagedRows
--WHERE RunGuid = '6B1E3E44-E503-4A25-8F43-79197D41A723'
--  AND RowStatus NOT IN (0,254)
--GROUP BY DifferenceType;


--SELECT
--    vi.RegistryGuid,
--    tr.SchemaName,
--    tr.TableName,
--    vi.SourceRowGuid,
--    vi.Severity,
--    vi.IssueCode,
--    vi.IssueMessage,
--    vi.DetailsJson
--FROM SMigration.Metadata_ValidationIssues AS vi
--LEFT JOIN SMigration.Metadata_TableRegistry AS tr
--    ON tr.Guid = vi.RegistryGuid
--   AND tr.RowStatus NOT IN (0,254)
--WHERE vi.RunGuid = '6B1E3E44-E503-4A25-8F43-79197D41A723'
--  AND vi.RowStatus NOT IN (0,254)
--ORDER BY
--    tr.ApplyOrder,
--    tr.SchemaName,
--    tr.TableName,
--    vi.SourceRowGuid;


--SELECT
--    DifferenceType,
--    COUNT_BIG(1) AS [RowCount]
--FROM SMigration.Metadata_StagedRows
--WHERE RunGuid = '6B1E3E44-E503-4A25-8F43-79197D41A723'
--  AND RowStatus NOT IN (0,254)
--GROUP BY DifferenceType
--ORDER BY DifferenceType;

--SELECT
--    tr.SchemaName,
--    tr.TableName,
--    sr.SourceRowGuid,
--    sr.SourceRowId,
--    sr.DifferenceType,
--    sr.SourcePayloadJson,
--    sr.TargetPayloadJson
--FROM SMigration.Metadata_StagedRows AS sr
--INNER JOIN SMigration.Metadata_TableRegistry AS tr
--    ON tr.Guid = sr.RegistryGuid
--   AND tr.RowStatus NOT IN (0,254)
--WHERE sr.RunGuid = '6B1E3E44-E503-4A25-8F43-79197D41A723'
--  AND sr.RowStatus NOT IN (0,254)
--  AND sr.DifferenceType IN (N'Insert', N'Update')
--ORDER BY
--    tr.ApplyOrder,
--    tr.SchemaName,
--    tr.TableName,
--    sr.SourceRowId;

--SELECT
--    maprow.SchemaName,
--    maprow.TableName,
--    sr.DifferenceType,
--    COUNT_BIG(1) AS MapRows,
--    SUM(CASE WHEN maprow.TargetRowId IS NULL THEN 1 ELSE 0 END) AS MissingTargetRows
--FROM SMigration.Metadata_ApplyIdentityMap AS maprow
--INNER JOIN SMigration.Metadata_StagedRows AS sr
--    ON sr.RunGuid = maprow.RunGuid
--   AND sr.RegistryGuid = maprow.RegistryGuid
--   AND sr.SourceRowGuid = maprow.SourceRowGuid
--   AND sr.RowStatus NOT IN (0,254)
--WHERE maprow.RunGuid = '6B1E3E44-E503-4A25-8F43-79197D41A723'
--  AND maprow.RowStatus NOT IN (0,254)
--GROUP BY
--    maprow.SchemaName,
--    maprow.TableName,
--    sr.DifferenceType
--ORDER BY
--    maprow.SchemaName,
--    maprow.TableName,
--    sr.DifferenceType;

--SELECT
--    s.name AS SchemaName,
--    p.name AS ProcedureName,
--    prm.parameter_id,
--    prm.name,
--    TYPE_NAME(prm.user_type_id) AS DataType,
--    prm.is_output
--FROM sys.procedures AS p
--INNER JOIN sys.schemas AS s
--    ON s.schema_id = p.schema_id
--INNER JOIN sys.parameters AS prm
--    ON prm.object_id = p.object_id
--WHERE s.name = N'SCore'
--  AND p.name = N'EntityQueryUpsert'
--ORDER BY prm.parameter_id;

