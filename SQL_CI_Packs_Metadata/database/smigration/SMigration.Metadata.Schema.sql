/* CI/CD-safe idempotent SMigration metadata schema deployment
   Generated from supplied MetaData Schema Scripts.sql on 2026-05-22.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    EXEC(N'CREATE SCHEMA [SMigration] AUTHORIZATION [dbo];');
GO

IF OBJECT_ID(N'SMigration.Metadata_ApplyIdentityMap', N'U') IS NULL
BEGIN
CREATE TABLE [SMigration].[Metadata_ApplyIdentityMap](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RunGuid] [uniqueidentifier] NOT NULL,
	[RegistryGuid] [uniqueidentifier] NOT NULL,
	[SchemaName] [sysname] NOT NULL,
	[TableName] [sysname] NOT NULL,
	[SourceRowGuid] [uniqueidentifier] NOT NULL,
	[SourceRowId] [bigint] NULL,
	[TargetRowId] [bigint] NULL,
	[CreatedOnUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Metadata_ApplyIdentityMap] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_ApplyIdentityMap_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_ApplyIdentityMap_Run_Table_Row] UNIQUE NONCLUSTERED 
(
	[RunGuid] ASC,
	[RegistryGuid] ASC,
	[SourceRowGuid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
END;
GO

IF OBJECT_ID(N'SMigration.Metadata_ExecutionLog', N'U') IS NULL
BEGIN
CREATE TABLE [SMigration].[Metadata_ExecutionLog](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RunGuid] [uniqueidentifier] NOT NULL,
	[StepName] [nvarchar](100) NOT NULL,
	[StepStatus] [nvarchar](30) NOT NULL,
	[Message] [nvarchar](2000) NOT NULL,
	[DetailsJson] [nvarchar](max) NOT NULL,
	[CreatedOnUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Metadata_ExecutionLog] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_ExecutionLog_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END;
GO

IF OBJECT_ID(N'SMigration.Metadata_Run', N'U') IS NULL
BEGIN
CREATE TABLE [SMigration].[Metadata_Run](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[SourceEnvironment] [nvarchar](20) NOT NULL,
	[TargetEnvironment] [nvarchar](20) NOT NULL,
	[SourceServerName] [nvarchar](255) NOT NULL,
	[SourceDatabaseName] [nvarchar](255) NOT NULL,
	[TargetServerName] [nvarchar](255) NOT NULL,
	[TargetDatabaseName] [nvarchar](255) NOT NULL,
	[RunStatus] [nvarchar](30) NOT NULL,
	[IsValidateOnly] [bit] NOT NULL,
	[CreatedOnUtc] [datetime2](7) NOT NULL,
	[ValidatedOnUtc] [datetime2](7) NULL,
	[AppliedOnUtc] [datetime2](7) NULL,
	[CreatedByUserId] [int] NOT NULL,
	[SummaryJson] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_Metadata_Run] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_Run_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END;
GO

IF OBJECT_ID(N'SMigration.Metadata_StagedRows', N'U') IS NULL
BEGIN
CREATE TABLE [SMigration].[Metadata_StagedRows](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RunGuid] [uniqueidentifier] NOT NULL,
	[RegistryGuid] [uniqueidentifier] NOT NULL,
	[SourceRowGuid] [uniqueidentifier] NOT NULL,
	[SourceRowId] [bigint] NULL,
	[SourceRowStatus] [tinyint] NULL,
	[SourcePayloadJson] [nvarchar](max) NOT NULL,
	[SourcePayloadHash] [varbinary](32) NOT NULL,
	[TargetPayloadJson] [nvarchar](max) NULL,
	[TargetPayloadHash] [varbinary](32) NULL,
	[DifferenceType] [nvarchar](30) NOT NULL,
	[CreatedOnUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Metadata_StagedRows] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_StagedRows_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_StagedRows_Run_Table_Row] UNIQUE NONCLUSTERED 
(
	[RunGuid] ASC,
	[RegistryGuid] ASC,
	[SourceRowGuid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END;
GO

IF OBJECT_ID(N'SMigration.Metadata_TableRegistry', N'U') IS NULL
BEGIN
CREATE TABLE [SMigration].[Metadata_TableRegistry](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[SchemaName] [sysname] NOT NULL,
	[TableName] [sysname] NOT NULL,
	[GuidColumnName] [sysname] NOT NULL,
	[PrimaryKeyColumnName] [sysname] NOT NULL,
	[ApplyOrder] [int] NOT NULL,
	[IsEnabled] [bit] NOT NULL,
	[IsDataObjectBacked] [bit] NOT NULL,
	[IsRetirable] [bit] NOT NULL,
	[IsEnvironmentSpecific] [bit] NOT NULL,
	[NaturalKeyJson] [nvarchar](max) NOT NULL,
	[ParentDependencyJson] [nvarchar](max) NOT NULL,
	[CreatedOnUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Metadata_TableRegistry] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_TableRegistry_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_TableRegistry_Table] UNIQUE NONCLUSTERED 
(
	[SchemaName] ASC,
	[TableName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END;
GO

IF OBJECT_ID(N'SMigration.Metadata_ValidationIssues', N'U') IS NULL
BEGIN
CREATE TABLE [SMigration].[Metadata_ValidationIssues](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RunGuid] [uniqueidentifier] NOT NULL,
	[RegistryGuid] [uniqueidentifier] NULL,
	[SourceRowGuid] [uniqueidentifier] NULL,
	[Severity] [nvarchar](20) NOT NULL,
	[IssueCode] [nvarchar](100) NOT NULL,
	[IssueMessage] [nvarchar](2000) NOT NULL,
	[DetailsJson] [nvarchar](max) NOT NULL,
	[CreatedOnUtc] [datetime2](7) NOT NULL,
 CONSTRAINT [PK_Metadata_ValidationIssues] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ_Metadata_ValidationIssues_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Metadata_ExecutionLog_RunGuid' AND object_id = OBJECT_ID(N'SMigration.Metadata_ExecutionLog'))
BEGIN
CREATE NONCLUSTERED INDEX [IX_Metadata_ExecutionLog_RunGuid] ON [SMigration].[Metadata_ExecutionLog]
(
	[RunGuid] ASC,
	[CreatedOnUtc] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Metadata_StagedRows_RunGuid' AND object_id = OBJECT_ID(N'SMigration.Metadata_StagedRows'))
BEGIN
CREATE NONCLUSTERED INDEX [IX_Metadata_StagedRows_RunGuid] ON [SMigration].[Metadata_StagedRows]
(
	[RunGuid] ASC,
	[RegistryGuid] ASC,
	[DifferenceType] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Metadata_TableRegistry_ApplyOrder' AND object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
CREATE NONCLUSTERED INDEX [IX_Metadata_TableRegistry_ApplyOrder] ON [SMigration].[Metadata_TableRegistry]
(
	[ApplyOrder] ASC,
	[SchemaName] ASC,
	[TableName] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [IsEnabled]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Metadata_ValidationIssues_RunGuid' AND object_id = OBJECT_ID(N'SMigration.Metadata_ValidationIssues'))
BEGIN
CREATE NONCLUSTERED INDEX [IX_Metadata_ValidationIssues_RunGuid] ON [SMigration].[Metadata_ValidationIssues]
(
	[RunGuid] ASC,
	[Severity] ASC,
	[IssueCode] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ApplyIdentityMap_RowStatus' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ApplyIdentityMap'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ApplyIdentityMap] ADD  CONSTRAINT [DF_Metadata_ApplyIdentityMap_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ApplyIdentityMap_CreatedOnUtc' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ApplyIdentityMap'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ApplyIdentityMap] ADD  CONSTRAINT [DF_Metadata_ApplyIdentityMap_CreatedOnUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedOnUtc]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ExecutionLog_RowStatus' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ExecutionLog'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ExecutionLog] ADD  CONSTRAINT [DF_Metadata_ExecutionLog_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ExecutionLog_Message' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ExecutionLog'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ExecutionLog] ADD  CONSTRAINT [DF_Metadata_ExecutionLog_Message]  DEFAULT (N'') FOR [Message]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ExecutionLog_DetailsJson' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ExecutionLog'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ExecutionLog] ADD  CONSTRAINT [DF_Metadata_ExecutionLog_DetailsJson]  DEFAULT (N'{}') FOR [DetailsJson]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ExecutionLog_CreatedOnUtc' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ExecutionLog'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ExecutionLog] ADD  CONSTRAINT [DF_Metadata_ExecutionLog_CreatedOnUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedOnUtc]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_Run_RowStatus' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_Run'))
BEGIN
ALTER TABLE [SMigration].[Metadata_Run] ADD  CONSTRAINT [DF_Metadata_Run_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_Run_IsValidateOnly' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_Run'))
BEGIN
ALTER TABLE [SMigration].[Metadata_Run] ADD  CONSTRAINT [DF_Metadata_Run_IsValidateOnly]  DEFAULT ((1)) FOR [IsValidateOnly]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_Run_CreatedOnUtc' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_Run'))
BEGIN
ALTER TABLE [SMigration].[Metadata_Run] ADD  CONSTRAINT [DF_Metadata_Run_CreatedOnUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedOnUtc]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_Run_CreatedByUserId' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_Run'))
BEGIN
ALTER TABLE [SMigration].[Metadata_Run] ADD  CONSTRAINT [DF_Metadata_Run_CreatedByUserId]  DEFAULT ((-1)) FOR [CreatedByUserId]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_Run_SummaryJson' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_Run'))
BEGIN
ALTER TABLE [SMigration].[Metadata_Run] ADD  CONSTRAINT [DF_Metadata_Run_SummaryJson]  DEFAULT (N'{}') FOR [SummaryJson]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_StagedRows_RowStatus' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_StagedRows'))
BEGIN
ALTER TABLE [SMigration].[Metadata_StagedRows] ADD  CONSTRAINT [DF_Metadata_StagedRows_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_StagedRows_CreatedOnUtc' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_StagedRows'))
BEGIN
ALTER TABLE [SMigration].[Metadata_StagedRows] ADD  CONSTRAINT [DF_Metadata_StagedRows_CreatedOnUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedOnUtc]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_RowStatus' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_GuidColumnName' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_GuidColumnName]  DEFAULT (N'Guid') FOR [GuidColumnName]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_PrimaryKeyColumnName' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_PrimaryKeyColumnName]  DEFAULT (N'ID') FOR [PrimaryKeyColumnName]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_IsEnabled' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_IsEnabled]  DEFAULT ((1)) FOR [IsEnabled]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_IsDataObjectBacked' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_IsDataObjectBacked]  DEFAULT ((1)) FOR [IsDataObjectBacked]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_IsRetirable' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_IsRetirable]  DEFAULT ((1)) FOR [IsRetirable]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_IsEnvironmentSpecific' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_IsEnvironmentSpecific]  DEFAULT ((0)) FOR [IsEnvironmentSpecific]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_NaturalKeyJson' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_NaturalKeyJson]  DEFAULT (N'[]') FOR [NaturalKeyJson]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_ParentDependencyJson' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_ParentDependencyJson]  DEFAULT (N'[]') FOR [ParentDependencyJson]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_TableRegistry_CreatedOnUtc' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_TableRegistry'))
BEGIN
ALTER TABLE [SMigration].[Metadata_TableRegistry] ADD  CONSTRAINT [DF_Metadata_TableRegistry_CreatedOnUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedOnUtc]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ValidationIssues_RowStatus' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ValidationIssues'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ValidationIssues] ADD  CONSTRAINT [DF_Metadata_ValidationIssues_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ValidationIssues_DetailsJson' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ValidationIssues'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ValidationIssues] ADD  CONSTRAINT [DF_Metadata_ValidationIssues_DetailsJson]  DEFAULT (N'{}') FOR [DetailsJson]
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.objects WHERE name = N'DF_Metadata_ValidationIssues_CreatedOnUtc' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_ValidationIssues'))
BEGIN
ALTER TABLE [SMigration].[Metadata_ValidationIssues] ADD  CONSTRAINT [DF_Metadata_ValidationIssues_CreatedOnUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedOnUtc]
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApply_Run]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ForceApply BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RunStatus NVARCHAR(30),
        @TargetEnvironment NVARCHAR(20),
        @SourceDatabaseName SYSNAME,
        @FailCount INT = 0;

    SELECT
        @RunStatus = r.RunStatus,
        @TargetEnvironment = r.TargetEnvironment,
        @SourceDatabaseName = r.SourceDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @RunStatus IS NULL
        THROW 52000, 'Metadata run was not found or is inactive.', 1;

    IF @RunStatus NOT IN (N'Validated', N'PartiallyApplied')
        THROW 52001, 'Metadata run must be Validated or PartiallyApplied before apply.', 1;

    SELECT
        @FailCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi
    INNER JOIN SMigration.Metadata_Run AS runScope
        ON runScope.Guid = vi.RunGuid
       AND runScope.RowStatus NOT IN (0,254)
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored
          WHERE ignored.DatabaseName = runScope.TargetDatabaseName
            AND ignored.RegistryGuid = vi.RegistryGuid
            AND ignored.SourceRowGuid = vi.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      );

    IF ISNULL(@FailCount, 0) > 0
        THROW 52002, 'Metadata run has validation failures and cannot be applied.', 1;

    IF @TargetEnvironment = N'LIVE' AND ISNULL(@ForceApply, 0) = 0
        THROW 52003, 'LIVE metadata apply requires @ForceApply = 1.', 1;

    BEGIN TRANSACTION;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyStart',
        @StepStatus = N'Started',
        @Message = N'Metadata apply started.',
        @DetailsJson = N'{}';

    /* =========================================================
       1. SCore.LanguageLabels
       ========================================================= */
    DECLARE
        @Guid UNIQUEIDENTIFIER,
        @Name NVARCHAR(500);

    DECLARE LanguageLabels_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name')
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'LanguageLabels'
        ORDER BY sr.SourceRowId;

    OPEN LanguageLabels_Cursor;

    FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelUpsert
            @Name = @Name,
            @Guid = @LanguageLabelGuid OUTPUT;

        FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;
    END;

    CLOSE LanguageLabels_Cursor;
    DEALLOCATE LanguageLabels_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabels',
        @StepStatus = N'Succeeded',
        @Message = N'Language labels applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       2. SCore.LanguageLabelTranslations
       ========================================================= */
    DECLARE
        @Text NVARCHAR(500),
        @TextPlural NVARCHAR(500),
        @HelpText NVARCHAR(MAX),
        @LanguageLabelGuidRef UNIQUEIDENTIFIER,
        @LanguageGuidRef UNIQUEIDENTIFIER,
        @SourceLanguageLabelId BIGINT,
        @SourceLanguageId BIGINT,
        @Sql NVARCHAR(MAX);

    IF OBJECT_ID(N'tempdb..#LanguageLabelTranslationsToApply') IS NOT NULL
        DROP TABLE #LanguageLabelTranslationsToApply;

    CREATE TABLE #LanguageLabelTranslationsToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        Text NVARCHAR(500) NULL,
        TextPlural NVARCHAR(500) NULL,
        HelpText NVARCHAR(MAX) NULL,
        SourceLanguageLabelId BIGINT NULL,
        SourceLanguageId BIGINT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #LanguageLabelTranslationsToApply
    (
        Guid,
        Text,
        TextPlural,
        HelpText,
        SourceLanguageLabelId,
        SourceLanguageId,
        SourceRowId
    )
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Text'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TextPlural'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.HelpText'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageID')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'LanguageLabelTranslations';

    DECLARE LanguageLabelTranslations_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            Text,
            TextPlural,
            HelpText,
            SourceLanguageLabelId,
            SourceLanguageId
        FROM #LanguageLabelTranslationsToApply
        ORDER BY SourceRowId;

    OPEN LanguageLabelTranslations_Cursor;

    FETCH NEXT FROM LanguageLabelTranslations_Cursor
    INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql = N'
SELECT
    @LanguageLabelGuidRef = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @SourceLanguageLabelId;

SELECT
    @LanguageGuidRef = l.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.Languages AS l
WHERE l.ID = @SourceLanguageId;';

        EXEC sys.sp_executesql
            @Sql,
            N'@SourceLanguageLabelId BIGINT, @SourceLanguageId BIGINT, @LanguageLabelGuidRef UNIQUEIDENTIFIER OUTPUT, @LanguageGuidRef UNIQUEIDENTIFIER OUTPUT',
            @SourceLanguageLabelId = @SourceLanguageLabelId,
            @SourceLanguageId = @SourceLanguageId,
            @LanguageLabelGuidRef = @LanguageLabelGuidRef OUTPUT,
            @LanguageGuidRef = @LanguageGuidRef OUTPUT;

        DECLARE @LanguageLabelTranslationGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelTranslationUpsert
            @Text = @Text,
            @TextPlural = @TextPlural,
            @HelpText = @HelpText,
            @LanguageLabelGuid = @LanguageLabelGuidRef,
            @LanguageGuid = @LanguageGuidRef,
            @Guid = @LanguageLabelTranslationGuid OUTPUT;

        FETCH NEXT FROM LanguageLabelTranslations_Cursor
        INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;
    END;

    CLOSE LanguageLabelTranslations_Cursor;
    DEALLOCATE LanguageLabelTranslations_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabelTranslations',
        @StepStatus = N'Succeeded',
        @Message = N'Language label translations applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       3. SCore.EntityQueries
       ========================================================= */
    DECLARE
        @Statement NVARCHAR(MAX),
        @EntityTypeGuid UNIQUEIDENTIFIER,
        @EntityHoBTGuid UNIQUEIDENTIFIER,
        @IsDefaultCreate BIT,
        @IsDefaultRead BIT,
        @IsDefaultUpdate BIT,
        @IsDefaultDelete BIT,
        @IsScalarExecute BIT,
        @IsDefaultValidation BIT,
        @IsDefaultDataPills BIT,
        @IsMergeDocumentQuery BIT,
        @IsProgressData BIT,
        @SchemaName NVARCHAR(255),
        @ObjectName NVARCHAR(255),
        @IsManualStatement BIT,
        @RowStatus TINYINT,
        @SourceEntityTypeId BIGINT,
        @SourceEntityHoBTId BIGINT;

    IF OBJECT_ID(N'tempdb..#EntityQueriesToApply') IS NOT NULL
        DROP TABLE #EntityQueriesToApply;

    CREATE TABLE #EntityQueriesToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        RowStatus TINYINT NULL,
        Name NVARCHAR(500) NULL,
        Statement NVARCHAR(MAX) NULL,
        SourceEntityTypeId BIGINT NULL,
        SourceEntityHoBTId BIGINT NULL,
        IsDefaultCreate BIT NULL,
        IsDefaultRead BIT NULL,
        IsDefaultUpdate BIT NULL,
        IsDefaultDelete BIT NULL,
        IsScalarExecute BIT NULL,
        IsDefaultValidation BIT NULL,
        IsDefaultDataPills BIT NULL,
        IsMergeDocumentQuery BIT NULL,
        IsProgressData BIT NULL,
        SchemaName NVARCHAR(255) NULL,
        ObjectName NVARCHAR(255) NULL,
        IsManualStatement BIT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #EntityQueriesToApply
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        jsonPayload.Statement,
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCreate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultRead')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultUpdate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDelete')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsScalarExecute')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultValidation')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDataPills')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMergeDocumentQuery')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsProgressData')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsManualStatement')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        Statement NVARCHAR(MAX) N'$.Statement'
    ) AS jsonPayload
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueries';

    DECLARE EntityQueries_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            RowStatus,
            Name,
            Statement,
            SourceEntityTypeId,
            SourceEntityHoBTId,
            IsDefaultCreate,
            IsDefaultRead,
            IsDefaultUpdate,
            IsDefaultDelete,
            IsScalarExecute,
            IsDefaultValidation,
            IsDefaultDataPills,
            IsMergeDocumentQuery,
            IsProgressData,
            SchemaName,
            ObjectName,
            IsManualStatement
        FROM #EntityQueriesToApply
        ORDER BY SourceRowId;

    OPEN EntityQueries_Cursor;

    FETCH NEXT FROM EntityQueries_Cursor
    INTO
        @Guid,
        @RowStatus,
        @Name,
        @Statement,
        @SourceEntityTypeId,
        @SourceEntityHoBTId,
        @IsDefaultCreate,
        @IsDefaultRead,
        @IsDefaultUpdate,
        @IsDefaultDelete,
        @IsScalarExecute,
        @IsDefaultValidation,
        @IsDefaultDataPills,
        @IsMergeDocumentQuery,
        @IsProgressData,
        @SchemaName,
        @ObjectName,
        @IsManualStatement;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql = N'
SELECT @EntityTypeGuid = et.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityTypes AS et
WHERE et.ID = @SourceEntityTypeId;

SELECT @EntityHoBTGuid = eh.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityHobts AS eh
WHERE eh.ID = @SourceEntityHoBTId;';

        EXEC sys.sp_executesql
            @Sql,
            N'@SourceEntityTypeId BIGINT, @SourceEntityHoBTId BIGINT, @EntityTypeGuid UNIQUEIDENTIFIER OUTPUT, @EntityHoBTGuid UNIQUEIDENTIFIER OUTPUT',
            @SourceEntityTypeId = @SourceEntityTypeId,
            @SourceEntityHoBTId = @SourceEntityHoBTId,
            @EntityTypeGuid = @EntityTypeGuid OUTPUT,
            @EntityHoBTGuid = @EntityHoBTGuid OUTPUT;

        DECLARE @EntityQueryGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityQueryUpsert
            @Name = @Name,
            @RowStatus = @RowStatus,
            @Statement = @Statement,
            @EntityTypeGuid = @EntityTypeGuid,
            @IsDefaultCreate = @IsDefaultCreate,
            @IsDefaultRead = @IsDefaultRead,
            @IsDefaultUpdate = @IsDefaultUpdate,
            @IsDefaultDelete = @IsDefaultDelete,
            @IsScalarExecute = @IsScalarExecute,
            @IsDefaultValidation = @IsDefaultValidation,
            @EntityHoBTGuid = @EntityHoBTGuid,
            @IsDefaultDataPills = @IsDefaultDataPills,
            @IsMergeDocumentQuery = @IsMergeDocumentQuery,
            @IsProgressData = @IsProgressData,
            @SchemaName = @SchemaName,
            @ObjectName = @ObjectName,
            @IsManualStatement = @IsManualStatement,
            @Guid = @EntityQueryGuid OUTPUT;

        FETCH NEXT FROM EntityQueries_Cursor
        INTO
            @Guid,
            @RowStatus,
            @Name,
            @Statement,
            @SourceEntityTypeId,
            @SourceEntityHoBTId,
            @IsDefaultCreate,
            @IsDefaultRead,
            @IsDefaultUpdate,
            @IsDefaultDelete,
            @IsScalarExecute,
            @IsDefaultValidation,
            @IsDefaultDataPills,
            @IsMergeDocumentQuery,
            @IsProgressData,
            @SchemaName,
            @ObjectName,
            @IsManualStatement;
    END;

    CLOSE EntityQueries_Cursor;
    DEALLOCATE EntityQueries_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityQueries',
        @StepStatus = N'Succeeded',
        @Message = N'Entity queries applied.',
        @DetailsJson = N'{}';

/* =========================================================
   4. SCore.EntityProperties
   ========================================================= */

DECLARE
    @EP_RowStatus TINYINT,
    @EP_Name NVARCHAR(500),
    @EP_SourceLanguageLabelID BIGINT,
    @EP_SourceEntityHoBTID BIGINT,
    @EP_SourceEntityDataTypeID BIGINT,
    @EP_SourceEntityPropertyGroupID BIGINT,
    @EP_SourceDropDownListDefinitionID BIGINT,
    @EP_LanguageLabelGuid UNIQUEIDENTIFIER,
    @EP_EntityHoBTGuid UNIQUEIDENTIFIER,
    @EP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EP_EntityPropertyGroupGuid UNIQUEIDENTIFIER,
    @EP_DropDownListDefinitionGuid UNIQUEIDENTIFIER,
    @EP_IsReadOnly BIT,
    @EP_IsImmutable BIT,
    @EP_IsUppercase BIT,
    @EP_IsHidden BIT,
    @EP_IsCompulsory BIT,
    @EP_MaxLength INT,
    @EP_Precision INT,
    @EP_Scale INT,
    @EP_DoNotTrackChanges BIT,
    @EP_SortOrder SMALLINT,
    @EP_GroupSortOrder SMALLINT,
    @EP_IsObjectLabel BIT,
    @EP_IsParentRelationship BIT,
    @EP_IsIncludedInformation BIT,
    @EP_IsLatitude BIT,
    @EP_IsLongitude BIT,
    @EP_FixDefaultValue NVARCHAR(100),
    @EP_SqlDefaultValueStatement NVARCHAR(MAX),
    @EP_AllowBulkChange BIT,
    @EP_IsVirtual BIT,
    @EP_ShowOnMobile BIT,
    @EP_IsAlwaysVisibleInGroup BIT,
    @EP_IsAlwaysVisibleInGroup_Mobile BIT;

IF OBJECT_ID(N'tempdb..#EntityPropertiesToApply') IS NOT NULL
    DROP TABLE #EntityPropertiesToApply;

CREATE TABLE #EntityPropertiesToApply
(
    Guid UNIQUEIDENTIFIER NOT NULL,
    RowStatus TINYINT NULL,
    Name NVARCHAR(500) NULL,
    SourceLanguageLabelID BIGINT NULL,
    SourceEntityHoBTID BIGINT NULL,
    SourceEntityDataTypeID BIGINT NULL,
    IsReadOnly BIT NULL,
    IsImmutable BIT NULL,
    IsUppercase BIT NULL,
    IsHidden BIT NULL,
    IsCompulsory BIT NULL,
    MaxLength INT NULL,
    PrecisionValue INT NULL,
    ScaleValue INT NULL,
    DoNotTrackChanges BIT NULL,
    SourceEntityPropertyGroupID BIGINT NULL,
    SortOrder SMALLINT NULL,
    GroupSortOrder SMALLINT NULL,
    IsObjectLabel BIT NULL,
    SourceDropDownListDefinitionID BIGINT NULL,
    IsParentRelationship BIT NULL,
    IsIncludedInformation BIT NULL,
    IsLatitude BIT NULL,
    IsLongitude BIT NULL,
    FixDefaultValue NVARCHAR(100) NULL,
    SqlDefaultValueStatement NVARCHAR(MAX) NULL,
    AllowBulkChange BIT NULL,
    IsVirtual BIT NULL,
    ShowOnMobile BIT NULL,
    IsAlwaysVisibleInGroup BIT NULL,
    IsAlwaysVisibleInGroup_Mobile BIT NULL,
    SourceRowId BIGINT NULL
);

INSERT INTO #EntityPropertiesToApply
SELECT
    sr.SourceRowGuid,
    TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
    JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID')),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID')),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnly')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsImmutable')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsUppercase')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCompulsory')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MaxLength')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Precision')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Scale')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupID')),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GroupSortOrder')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsObjectLabel')),
    TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionID')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsParentRelationship')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsIncludedInformation')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLatitude')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLongitude')),
    ISNULL
    (
        COALESCE
        (
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixedDefaultValue'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixDefaultValue')
        ),
        N''
    ),
    epjson.SqlDefaultValueStatement,
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsVirtual')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup_Mobile')),
    sr.SourceRowId
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = sr.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
OUTER APPLY OPENJSON(sr.SourcePayloadJson)
WITH
(
    SqlDefaultValueStatement NVARCHAR(MAX) N'$.SqlDefaultValueStatement'
) AS epjson
WHERE sr.RunGuid = @RunGuid
  AND sr.RowStatus NOT IN (0,254)
  AND sr.DifferenceType IN (N'Insert', N'Update')
  AND tr.SchemaName = N'SCore'
  AND tr.TableName = N'EntityProperties';

DECLARE EntityProperties_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        Guid,
        RowStatus,
        Name,
        SourceLanguageLabelID,
        SourceEntityHoBTID,
        SourceEntityDataTypeID,
        IsReadOnly,
        IsImmutable,
        IsUppercase,
        IsHidden,
        IsCompulsory,
        MaxLength,
        PrecisionValue,
        ScaleValue,
        DoNotTrackChanges,
        SourceEntityPropertyGroupID,
        SortOrder,
        GroupSortOrder,
        IsObjectLabel,
        SourceDropDownListDefinitionID,
        IsParentRelationship,
        IsIncludedInformation,
        IsLatitude,
        IsLongitude,
        FixDefaultValue,
        SqlDefaultValueStatement,
        AllowBulkChange,
        IsVirtual,
        ShowOnMobile,
        IsAlwaysVisibleInGroup,
        IsAlwaysVisibleInGroup_Mobile
    FROM #EntityPropertiesToApply
    ORDER BY SourceRowId;

OPEN EntityProperties_Cursor;

FETCH NEXT FROM EntityProperties_Cursor
INTO
    @Guid,
    @EP_RowStatus,
    @EP_Name,
    @EP_SourceLanguageLabelID,
    @EP_SourceEntityHoBTID,
    @EP_SourceEntityDataTypeID,
    @EP_IsReadOnly,
    @EP_IsImmutable,
    @EP_IsUppercase,
    @EP_IsHidden,
    @EP_IsCompulsory,
    @EP_MaxLength,
    @EP_Precision,
    @EP_Scale,
    @EP_DoNotTrackChanges,
    @EP_SourceEntityPropertyGroupID,
    @EP_SortOrder,
    @EP_GroupSortOrder,
    @EP_IsObjectLabel,
    @EP_SourceDropDownListDefinitionID,
    @EP_IsParentRelationship,
    @EP_IsIncludedInformation,
    @EP_IsLatitude,
    @EP_IsLongitude,
    @EP_FixDefaultValue,
    @EP_SqlDefaultValueStatement,
    @EP_AllowBulkChange,
    @EP_IsVirtual,
    @EP_ShowOnMobile,
    @EP_IsAlwaysVisibleInGroup,
    @EP_IsAlwaysVisibleInGroup_Mobile;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EP_LanguageLabelGuid = NULL;
    SET @EP_EntityHoBTGuid = NULL;
    SET @EP_EntityDataTypeGuid = NULL;
    SET @EP_EntityPropertyGroupGuid = NULL;
    SET @EP_DropDownListDefinitionGuid = NULL;
    SET @EP_FixDefaultValue = ISNULL(@EP_FixDefaultValue, N'');
    SET @Sql = N'
SELECT @EP_LanguageLabelGuid = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @EP_SourceLanguageLabelID;

SELECT @EP_EntityHoBTGuid = eh.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityHobts AS eh
WHERE eh.ID = @EP_SourceEntityHoBTID;

SELECT @EP_EntityDataTypeGuid = edt.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityDataTypes AS edt
WHERE edt.ID = @EP_SourceEntityDataTypeID;

SELECT @EP_EntityPropertyGroupGuid = epg.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityPropertyGroups AS epg
WHERE epg.ID = @EP_SourceEntityPropertyGroupID;

SELECT @EP_DropDownListDefinitionGuid = ddl.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.DropDownListDefinitions AS ddl
WHERE ddl.ID = @EP_SourceDropDownListDefinitionID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@EP_SourceLanguageLabelID BIGINT,
          @EP_SourceEntityHoBTID BIGINT,
          @EP_SourceEntityDataTypeID BIGINT,
          @EP_SourceEntityPropertyGroupID BIGINT,
          @EP_SourceDropDownListDefinitionID BIGINT,
          @EP_LanguageLabelGuid UNIQUEIDENTIFIER OUTPUT,
          @EP_EntityHoBTGuid UNIQUEIDENTIFIER OUTPUT,
          @EP_EntityDataTypeGuid UNIQUEIDENTIFIER OUTPUT,
          @EP_EntityPropertyGroupGuid UNIQUEIDENTIFIER OUTPUT,
          @EP_DropDownListDefinitionGuid UNIQUEIDENTIFIER OUTPUT',
        @EP_SourceLanguageLabelID = @EP_SourceLanguageLabelID,
        @EP_SourceEntityHoBTID = @EP_SourceEntityHoBTID,
        @EP_SourceEntityDataTypeID = @EP_SourceEntityDataTypeID,
        @EP_SourceEntityPropertyGroupID = @EP_SourceEntityPropertyGroupID,
        @EP_SourceDropDownListDefinitionID = @EP_SourceDropDownListDefinitionID,
        @EP_LanguageLabelGuid = @EP_LanguageLabelGuid OUTPUT,
        @EP_EntityHoBTGuid = @EP_EntityHoBTGuid OUTPUT,
        @EP_EntityDataTypeGuid = @EP_EntityDataTypeGuid OUTPUT,
        @EP_EntityPropertyGroupGuid = @EP_EntityPropertyGroupGuid OUTPUT,
        @EP_DropDownListDefinitionGuid = @EP_DropDownListDefinitionGuid OUTPUT;

    DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SCore.EntityPropertyUpsert
        @Name = @EP_Name,
        @RowStatus = @EP_RowStatus,
        @LanguageLabelGuid = @EP_LanguageLabelGuid,
        @EntityHobtGuid = @EP_EntityHoBTGuid,
        @EntityDataTypeGuid = @EP_EntityDataTypeGuid,
        @IsReadOnly = @EP_IsReadOnly,
        @IsImmutable = @EP_IsImmutable,
        @IsUppercase = @EP_IsUppercase,
        @IsHidden = @EP_IsHidden,
        @IsCompulsory = @EP_IsCompulsory,
        @MaxLength = @EP_MaxLength,
        @Precision = @EP_Precision,
        @Scale = @EP_Scale,
        @DoNotTrackChanges = @EP_DoNotTrackChanges,
        @EntityPropertyGroupGuid = @EP_EntityPropertyGroupGuid,
        @SortOrder = @EP_SortOrder,
        @GroupSortOrder = @EP_GroupSortOrder,
        @IsObjectLabel = @EP_IsObjectLabel,
        @DropDownListDefinitionGuid = @EP_DropDownListDefinitionGuid,
        @IsParentRelationship = @EP_IsParentRelationship,
        @IsIncludedInformation = @EP_IsIncludedInformation,
        @IsLatitude = @EP_IsLatitude,
        @IsLongitude = @EP_IsLongitude,
        @FixDefaultValue = @EP_FixDefaultValue,
        @SqlDefaultValueStatement = @EP_SqlDefaultValueStatement,
        @AllowBulkChange = @EP_AllowBulkChange,
        @IsVirtual = @EP_IsVirtual,
        @ShowOnMobile = @EP_ShowOnMobile,
        @IsAlwaysVisibleInGroup = @EP_IsAlwaysVisibleInGroup,
        @IsAlwaysVisibleInGroup_Mobile = @EP_IsAlwaysVisibleInGroup_Mobile,
        @Guid = @EntityPropertyGuid OUTPUT;

    FETCH NEXT FROM EntityProperties_Cursor
    INTO
        @Guid,
        @EP_RowStatus,
        @EP_Name,
        @EP_SourceLanguageLabelID,
        @EP_SourceEntityHoBTID,
        @EP_SourceEntityDataTypeID,
        @EP_IsReadOnly,
        @EP_IsImmutable,
        @EP_IsUppercase,
        @EP_IsHidden,
        @EP_IsCompulsory,
        @EP_MaxLength,
        @EP_Precision,
        @EP_Scale,
        @EP_DoNotTrackChanges,
        @EP_SourceEntityPropertyGroupID,
        @EP_SortOrder,
        @EP_GroupSortOrder,
        @EP_IsObjectLabel,
        @EP_SourceDropDownListDefinitionID,
        @EP_IsParentRelationship,
        @EP_IsIncludedInformation,
        @EP_IsLatitude,
        @EP_IsLongitude,
        @EP_FixDefaultValue,
        @EP_SqlDefaultValueStatement,
        @EP_AllowBulkChange,
        @EP_IsVirtual,
        @EP_ShowOnMobile,
        @EP_IsAlwaysVisibleInGroup,
        @EP_IsAlwaysVisibleInGroup_Mobile;
END;

CLOSE EntityProperties_Cursor;
DEALLOCATE EntityProperties_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityProperties',
    @StepStatus = N'Succeeded',
    @Message = N'Entity properties applied.',
    @DetailsJson = N'{}';

/* =========================================================
   5. SCore.EntityQueryParameters
   ========================================================= */

DECLARE
    @EQP_RowStatus TINYINT,
    @EQP_Name NVARCHAR(500),
    @EQP_SourceEntityQueryID BIGINT,
    @EQP_SourceEntityDataTypeID BIGINT,
    @EQP_SourceMappedEntityPropertyID BIGINT,
    @EQP_EntityQueryGuid UNIQUEIDENTIFIER,
    @EQP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EQP_MappedEntityPropertyGuid UNIQUEIDENTIFIER,
    @EQP_DefaultValue NVARCHAR(200),
    @EQP_IsInput BIT,
    @EQP_IsOutput BIT,
    @EQP_IsReturnColumn BIT;

DECLARE EntityQueryParameters_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyID')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultValue'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsInput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsOutput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReturnColumn'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueryParameters'
    ORDER BY sr.SourceRowId;

OPEN EntityQueryParameters_Cursor;

FETCH NEXT FROM EntityQueryParameters_Cursor
INTO
    @Guid,
    @EQP_RowStatus,
    @EQP_Name,
    @EQP_SourceEntityQueryID,
    @EQP_SourceEntityDataTypeID,
    @EQP_SourceMappedEntityPropertyID,
    @EQP_DefaultValue,
    @EQP_IsInput,
    @EQP_IsOutput,
    @EQP_IsReturnColumn;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EQP_EntityQueryGuid = NULL;
    SET @EQP_EntityDataTypeGuid = NULL;
    SET @EQP_MappedEntityPropertyGuid = NULL;

    SET @Sql = N'
SELECT @EQP_EntityQueryGuid = eq.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityQueries AS eq
WHERE eq.ID = @EQP_SourceEntityQueryID;

SELECT @EQP_EntityDataTypeGuid = edt.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityDataTypes AS edt
WHERE edt.ID = @EQP_SourceEntityDataTypeID;

SELECT @EQP_MappedEntityPropertyGuid = ep.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityProperties AS ep
WHERE ep.ID = @EQP_SourceMappedEntityPropertyID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@EQP_SourceEntityQueryID BIGINT,
          @EQP_SourceEntityDataTypeID BIGINT,
          @EQP_SourceMappedEntityPropertyID BIGINT,
          @EQP_EntityQueryGuid UNIQUEIDENTIFIER OUTPUT,
          @EQP_EntityDataTypeGuid UNIQUEIDENTIFIER OUTPUT,
          @EQP_MappedEntityPropertyGuid UNIQUEIDENTIFIER OUTPUT',
        @EQP_SourceEntityQueryID = @EQP_SourceEntityQueryID,
        @EQP_SourceEntityDataTypeID = @EQP_SourceEntityDataTypeID,
        @EQP_SourceMappedEntityPropertyID = @EQP_SourceMappedEntityPropertyID,
        @EQP_EntityQueryGuid = @EQP_EntityQueryGuid OUTPUT,
        @EQP_EntityDataTypeGuid = @EQP_EntityDataTypeGuid OUTPUT,
        @EQP_MappedEntityPropertyGuid = @EQP_MappedEntityPropertyGuid OUTPUT;

    DECLARE @EntityQueryParameterGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SCore.EntityQueryParameterUpsert
        @Name = @EQP_Name,
        @RowStatus = @EQP_RowStatus,
        @EntityQueryGuid = @EQP_EntityQueryGuid,
        @EntityDataTypeGuid = @EQP_EntityDataTypeGuid,
        @MappedEntityPropertyGuid = @EQP_MappedEntityPropertyGuid,
        @DefaultValue = @EQP_DefaultValue,
        @IsInput = @EQP_IsInput,
        @IsOutput = @EQP_IsOutput,
        @IsReturnColumn = @EQP_IsReturnColumn,
        @Guid = @EntityQueryParameterGuid OUTPUT;

    FETCH NEXT FROM EntityQueryParameters_Cursor
    INTO
        @Guid,
        @EQP_RowStatus,
        @EQP_Name,
        @EQP_SourceEntityQueryID,
        @EQP_SourceEntityDataTypeID,
        @EQP_SourceMappedEntityPropertyID,
        @EQP_DefaultValue,
        @EQP_IsInput,
        @EQP_IsOutput,
        @EQP_IsReturnColumn;
END;

CLOSE EntityQueryParameters_Cursor;
DEALLOCATE EntityQueryParameters_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityQueryParameters',
    @StepStatus = N'Succeeded',
    @Message = N'Entity query parameters applied.',
    @DetailsJson = N'{}';


/* =========================================================
   6. SUserInterface.GridDefinitions
   ========================================================= */

DECLARE
    @GD_RowStatus TINYINT,
    @GD_Code NVARCHAR(30),
    @GD_TabName NVARCHAR(250),
    @GD_ShowAsTiles BIT,
    @GD_PageUri NVARCHAR(250),
    @GD_SourceLanguageLabelID BIGINT,
    @GD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TabName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowAsTiles')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.PageUri'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridDefinitions_Cursor;

FETCH NEXT FROM GridDefinitions_Cursor
INTO
    @Guid,
    @GD_RowStatus,
    @GD_Code,
    @GD_TabName,
    @GD_ShowAsTiles,
    @GD_PageUri,
    @GD_SourceLanguageLabelID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GD_LanguageLabelGuid = NULL;

    SET @Sql = N'
SELECT @GD_LanguageLabelGuid = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @GD_SourceLanguageLabelID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@GD_SourceLanguageLabelID BIGINT,
          @GD_LanguageLabelGuid UNIQUEIDENTIFIER OUTPUT',
        @GD_SourceLanguageLabelID = @GD_SourceLanguageLabelID,
        @GD_LanguageLabelGuid = @GD_LanguageLabelGuid OUTPUT;

    DECLARE @GridDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridDefinitionUpsert
        @Code = @GD_Code,
        @RowStatus = @GD_RowStatus,
        @TabName = @GD_TabName,
        @ShowAsTiles = @GD_ShowAsTiles,
        @PageUri = @GD_PageUri,
        @LanguageLabelGuid = @GD_LanguageLabelGuid,
        @Guid = @GridDefinitionGuid OUTPUT;

    FETCH NEXT FROM GridDefinitions_Cursor
    INTO
        @Guid,
        @GD_RowStatus,
        @GD_Code,
        @GD_TabName,
        @GD_ShowAsTiles,
        @GD_PageUri,
        @GD_SourceLanguageLabelID;
END;

CLOSE GridDefinitions_Cursor;
DEALLOCATE GridDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   7. SUserInterface.GridViewDefinitions
   ========================================================= */

DECLARE
    @GVD_RowStatus TINYINT,
    @GVD_Code NVARCHAR(20),
    @GVD_SourceGridDefinitionID BIGINT,
    @GVD_DetailPageUri NVARCHAR(250),
    @GVD_SqlQuery NVARCHAR(MAX),
    @GVD_DefaultSortColumnName NVARCHAR(250),
    @GVD_SecurableCode NVARCHAR(20),
    @GVD_DisplayOrder INT,
    @GVD_DisplayGroupName NVARCHAR(50),
    @GVD_MetricSqlQuery NVARCHAR(MAX),
    @GVD_ShowMetric BIT,
    @GVD_IsDetailWindowed BIT,
    @GVD_SourceEntityTypeID BIGINT,
    @GVD_SourceMetricTypeID BIGINT,
    @GVD_MetricMin INT,
    @GVD_MetricMax INT,
    @GVD_MetricMinorUnit INT,
    @GVD_MetricMajorUnit INT,
    @GVD_MetricStartAngle INT,
    @GVD_MetricEndAngle INT,
    @GVD_MetricReversed BIT,
    @GVD_MetricRange1Min DECIMAL(18,0),
    @GVD_MetricRange1Max DECIMAL(18,0),
    @GVD_MetricRange1ColourHex NVARCHAR(10),
    @GVD_MetricRange2Min DECIMAL(18,0),
    @GVD_MetricRange2Max DECIMAL(18,0),
    @GVD_MetricRange2ColourHex NVARCHAR(10),
    @GVD_IsDefaultSortDescending BIT,
    @GVD_ShowOnMobile BIT,
    @GVD_AllowNew BIT,
    @GVD_AllowExcelExport BIT,
    @GVD_AllowPdfExport BIT,
    @GVD_AllowCsvExport BIT,
    @GVD_SourceLanguageLabelID BIGINT,
    @GVD_SourceDrawerIconID BIGINT,
    @GVD_SourceGridViewTypeID BIGINT,
    @GVD_AllowBulkChange BIT,
    @GVD_TreeListFirstOrderBy NVARCHAR(100),
    @GVD_TreeListSecondOrderBy NVARCHAR(100),
    @GVD_TreeListThirdOrderBy NVARCHAR(100),
    @GVD_TreeListOrderBy NVARCHAR(100),
    @GVD_TreeListGroupBy NVARCHAR(100),
    @GVD_ShowOnDashboard BIT,
    @GVD_FilteredListCreatedOnColumn NVARCHAR(100),
    @GVD_FilteredListRedStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListOrangeStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGreenStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGroupBy NVARCHAR(100),
    @GVD_IsHidden BIT,
    @GVD_GridDefinitionGuid UNIQUEIDENTIFIER,
    @GVD_EntityTypeGuid UNIQUEIDENTIFIER,
    @GVD_MetricTypeGuid UNIQUEIDENTIFIER,
    @GVD_LanguageLabelGuid UNIQUEIDENTIFIER,
    @GVD_DrawerIconGuid UNIQUEIDENTIFIER,
    @GVD_GridViewTypeGuid UNIQUEIDENTIFIER;

DECLARE GridViewDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionId')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUri'),
        jsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SecurableCode'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayOrder')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayGroupName'),
        jsonValues.MetricSqlQuery,
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowMetric')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeID')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMin')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMax')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMinorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMajorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricStartAngle')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricEndAngle')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricReversed')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1ColourHex'),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2ColourHex'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultSortDescending')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowNew')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowExcelExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowPdfExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowCsvExport')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconId')),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeId')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListFirstOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListSecondOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListThirdOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnDashboard')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListCreatedOnColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListRedStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListOrangeStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGreenStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery',
        MetricSqlQuery NVARCHAR(MAX) N'$.MetricSqlQuery'
    ) AS jsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewDefinitions_Cursor;

FETCH NEXT FROM GridViewDefinitions_Cursor
INTO
    @Guid,
    @GVD_RowStatus,
    @GVD_Code,
    @GVD_SourceGridDefinitionID,
    @GVD_DetailPageUri,
    @GVD_SqlQuery,
    @GVD_DefaultSortColumnName,
    @GVD_SecurableCode,
    @GVD_DisplayOrder,
    @GVD_DisplayGroupName,
    @GVD_MetricSqlQuery,
    @GVD_ShowMetric,
    @GVD_IsDetailWindowed,
    @GVD_SourceEntityTypeID,
    @GVD_SourceMetricTypeID,
    @GVD_MetricMin,
    @GVD_MetricMax,
    @GVD_MetricMinorUnit,
    @GVD_MetricMajorUnit,
    @GVD_MetricStartAngle,
    @GVD_MetricEndAngle,
    @GVD_MetricReversed,
    @GVD_MetricRange1Min,
    @GVD_MetricRange1Max,
    @GVD_MetricRange1ColourHex,
    @GVD_MetricRange2Min,
    @GVD_MetricRange2Max,
    @GVD_MetricRange2ColourHex,
    @GVD_IsDefaultSortDescending,
    @GVD_ShowOnMobile,
    @GVD_AllowNew,
    @GVD_AllowExcelExport,
    @GVD_AllowPdfExport,
    @GVD_AllowCsvExport,
    @GVD_SourceLanguageLabelID,
    @GVD_SourceDrawerIconID,
    @GVD_SourceGridViewTypeID,
    @GVD_AllowBulkChange,
    @GVD_TreeListFirstOrderBy,
    @GVD_TreeListSecondOrderBy,
    @GVD_TreeListThirdOrderBy,
    @GVD_TreeListOrderBy,
    @GVD_TreeListGroupBy,
    @GVD_ShowOnDashboard,
    @GVD_FilteredListCreatedOnColumn,
    @GVD_FilteredListRedStatusIndicatorTxt,
    @GVD_FilteredListOrangeStatusIndicatorTxt,
    @GVD_FilteredListGreenStatusIndicatorTxt,
    @GVD_FilteredListGroupBy,
    @GVD_IsHidden;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVD_GridDefinitionGuid = NULL;
    SET @GVD_EntityTypeGuid = NULL;
    SET @GVD_MetricTypeGuid = NULL;
    SET @GVD_LanguageLabelGuid = NULL;
    SET @GVD_DrawerIconGuid = NULL;
    SET @GVD_GridViewTypeGuid = NULL;

    SET @Sql = N'
SELECT @GVD_GridDefinitionGuid = gd.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.GridDefinitions AS gd
WHERE gd.ID = @GVD_SourceGridDefinitionID;

SELECT @GVD_EntityTypeGuid = et.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityTypes AS et
WHERE et.ID = @GVD_SourceEntityTypeID;

SELECT @GVD_MetricTypeGuid = mt.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.MetricTypes AS mt
WHERE mt.ID = @GVD_SourceMetricTypeID;

SELECT @GVD_LanguageLabelGuid = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @GVD_SourceLanguageLabelID;

SELECT @GVD_DrawerIconGuid = i.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.Icons AS i
WHERE i.ID = @GVD_SourceDrawerIconID;

SELECT @GVD_GridViewTypeGuid = gvt.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.GridViewTypes AS gvt
WHERE gvt.ID = @GVD_SourceGridViewTypeID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@GVD_SourceGridDefinitionID BIGINT,
          @GVD_SourceEntityTypeID BIGINT,
          @GVD_SourceMetricTypeID BIGINT,
          @GVD_SourceLanguageLabelID BIGINT,
          @GVD_SourceDrawerIconID BIGINT,
          @GVD_SourceGridViewTypeID BIGINT,
          @GVD_GridDefinitionGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_EntityTypeGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_MetricTypeGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_LanguageLabelGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_DrawerIconGuid UNIQUEIDENTIFIER OUTPUT,
          @GVD_GridViewTypeGuid UNIQUEIDENTIFIER OUTPUT',
        @GVD_SourceGridDefinitionID = @GVD_SourceGridDefinitionID,
        @GVD_SourceEntityTypeID = @GVD_SourceEntityTypeID,
        @GVD_SourceMetricTypeID = @GVD_SourceMetricTypeID,
        @GVD_SourceLanguageLabelID = @GVD_SourceLanguageLabelID,
        @GVD_SourceDrawerIconID = @GVD_SourceDrawerIconID,
        @GVD_SourceGridViewTypeID = @GVD_SourceGridViewTypeID,
        @GVD_GridDefinitionGuid = @GVD_GridDefinitionGuid OUTPUT,
        @GVD_EntityTypeGuid = @GVD_EntityTypeGuid OUTPUT,
        @GVD_MetricTypeGuid = @GVD_MetricTypeGuid OUTPUT,
        @GVD_LanguageLabelGuid = @GVD_LanguageLabelGuid OUTPUT,
        @GVD_DrawerIconGuid = @GVD_DrawerIconGuid OUTPUT,
        @GVD_GridViewTypeGuid = @GVD_GridViewTypeGuid OUTPUT;

    DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridViewDefinitionUpsert
        @Code = @GVD_Code,
        @RowStatus = @GVD_RowStatus,
        @GridDefinitionGuid = @GVD_GridDefinitionGuid,
        @DetailPageUri = @GVD_DetailPageUri,
        @SqlQuery = @GVD_SqlQuery,
        @DefaultSortColumnName = @GVD_DefaultSortColumnName,
        @SecurableCode = @GVD_SecurableCode,
        @DisplayOrder = @GVD_DisplayOrder,
        @DisplayGroupName = @GVD_DisplayGroupName,
        @MetricSqlQuery = @GVD_MetricSqlQuery,
        @ShowMetric = @GVD_ShowMetric,
        @IsDetailWindowed = @GVD_IsDetailWindowed,
        @EntityTypeGuid = @GVD_EntityTypeGuid,
        @MetricTypeGuid = @GVD_MetricTypeGuid,
        @MetricMin = @GVD_MetricMin,
        @MetricMax = @GVD_MetricMax,
        @MetricMinorUnit = @GVD_MetricMinorUnit,
        @MetricMajorUnit = @GVD_MetricMajorUnit,
        @MetricStartAngle = @GVD_MetricStartAngle,
        @MetricEndAngle = @GVD_MetricEndAngle,
        @MetricReversed = @GVD_MetricReversed,
        @MetricRange1Min = @GVD_MetricRange1Min,
        @MetricRange1Max = @GVD_MetricRange1Max,
        @MetricRange1ColourHex = @GVD_MetricRange1ColourHex,
        @MetricRange2Min = @GVD_MetricRange2Min,
        @MetricRange2Max = @GVD_MetricRange2Max,
        @MetricRange2ColourHex = @GVD_MetricRange2ColourHex,
        @IsDefaultSortDescending = @GVD_IsDefaultSortDescending,
        @AllowNew = @GVD_AllowNew,
        @AllowExcelExport = @GVD_AllowExcelExport,
        @AllowPdfExport = @GVD_AllowPdfExport,
        @AllowCsvExport = @GVD_AllowCsvExport,
        @LanguageLabelGuid = @GVD_LanguageLabelGuid,
        @DrawerIconGuid = @GVD_DrawerIconGuid,
        @GridViewTypeGuid = @GVD_GridViewTypeGuid,
        @AllowBulkChange = @GVD_AllowBulkChange,
        @Guid = @GridViewDefinitionGuid OUTPUT,
        @ShowOnMobile = @GVD_ShowOnMobile,
        @TreeListFirstOrderBy = @GVD_TreeListFirstOrderBy,
        @TreeListSecondOrderBy = @GVD_TreeListSecondOrderBy,
        @TreeListThirdOrderBy = @GVD_TreeListThirdOrderBy,
        @TreeListOrderBy = @GVD_TreeListOrderBy,
        @TreeListGroupBy = @GVD_TreeListGroupBy,
        @ShowOnDashboard = @GVD_ShowOnDashboard,
        @FilteredListCreatedOnColumn = @GVD_FilteredListCreatedOnColumn,
        @FilteredListRedStatusIndicatorTxt = @GVD_FilteredListRedStatusIndicatorTxt,
        @FilteredListOrangeStatusIndicatorTxt = @GVD_FilteredListOrangeStatusIndicatorTxt,
        @FilteredListGreenStatusIndicatorTxt = @GVD_FilteredListGreenStatusIndicatorTxt,
        @FilteredListGroupBy = @GVD_FilteredListGroupBy,
        @IsHidden = @GVD_IsHidden;

    FETCH NEXT FROM GridViewDefinitions_Cursor
    INTO
        @Guid,
        @GVD_RowStatus,
        @GVD_Code,
        @GVD_SourceGridDefinitionID,
        @GVD_DetailPageUri,
        @GVD_SqlQuery,
        @GVD_DefaultSortColumnName,
        @GVD_SecurableCode,
        @GVD_DisplayOrder,
        @GVD_DisplayGroupName,
        @GVD_MetricSqlQuery,
        @GVD_ShowMetric,
        @GVD_IsDetailWindowed,
        @GVD_SourceEntityTypeID,
        @GVD_SourceMetricTypeID,
        @GVD_MetricMin,
        @GVD_MetricMax,
        @GVD_MetricMinorUnit,
        @GVD_MetricMajorUnit,
        @GVD_MetricStartAngle,
        @GVD_MetricEndAngle,
        @GVD_MetricReversed,
        @GVD_MetricRange1Min,
        @GVD_MetricRange1Max,
        @GVD_MetricRange1ColourHex,
        @GVD_MetricRange2Min,
        @GVD_MetricRange2Max,
        @GVD_MetricRange2ColourHex,
        @GVD_IsDefaultSortDescending,
        @GVD_ShowOnMobile,
        @GVD_AllowNew,
        @GVD_AllowExcelExport,
        @GVD_AllowPdfExport,
        @GVD_AllowCsvExport,
        @GVD_SourceLanguageLabelID,
        @GVD_SourceDrawerIconID,
        @GVD_SourceGridViewTypeID,
        @GVD_AllowBulkChange,
        @GVD_TreeListFirstOrderBy,
        @GVD_TreeListSecondOrderBy,
        @GVD_TreeListThirdOrderBy,
        @GVD_TreeListOrderBy,
        @GVD_TreeListGroupBy,
        @GVD_ShowOnDashboard,
        @GVD_FilteredListCreatedOnColumn,
        @GVD_FilteredListRedStatusIndicatorTxt,
        @GVD_FilteredListOrangeStatusIndicatorTxt,
        @GVD_FilteredListGreenStatusIndicatorTxt,
        @GVD_FilteredListGroupBy,
        @GVD_IsHidden;
END;

CLOSE GridViewDefinitions_Cursor;
DEALLOCATE GridViewDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   8. SUserInterface.GridViewColumnDefinitions
   ========================================================= */

DECLARE
    @GVCD_RowStatus TINYINT,
    @GVCD_Name NVARCHAR(250),
    @GVCD_SourceGridViewDefinitionID BIGINT,
    @GVCD_ColumnOrder INT,
    @GVCD_IsPrimaryKey BIT,
    @GVCD_IsHidden BIT,
    @GVCD_IsFiltered BIT,
    @GVCD_IsCombo BIT,
    @GVCD_DisplayFormat NVARCHAR(50),
    @GVCD_Width NVARCHAR(10),
    @GVCD_SourceLanguageLabelID BIGINT,
    @GVCD_TopHeaderCategory NVARCHAR(50),
    @GVCD_TopHeaderCategoryOrder INT,
    @GVCD_GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridViewColumnDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionId')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.ColumnOrder')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsPrimaryKey')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsFiltered')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCombo')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayFormat'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Width'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategory'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategoryOrder'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewColumnDefinitions_Cursor;

FETCH NEXT FROM GridViewColumnDefinitions_Cursor
INTO
    @Guid,
    @GVCD_RowStatus,
    @GVCD_Name,
    @GVCD_SourceGridViewDefinitionID,
    @GVCD_ColumnOrder,
    @GVCD_IsPrimaryKey,
    @GVCD_IsHidden,
    @GVCD_IsFiltered,
    @GVCD_IsCombo,
    @GVCD_DisplayFormat,
    @GVCD_Width,
    @GVCD_SourceLanguageLabelID,
    @GVCD_TopHeaderCategory,
    @GVCD_TopHeaderCategoryOrder;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVCD_GridViewDefinitionGuid = NULL;
    SET @GVCD_LanguageLabelGuid = NULL;

    SET @Sql = N'
SELECT @GVCD_GridViewDefinitionGuid = gvd.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SUserInterface.GridViewDefinitions AS gvd
WHERE gvd.ID = @GVCD_SourceGridViewDefinitionID;

SELECT @GVCD_LanguageLabelGuid = ll.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.LanguageLabels AS ll
WHERE ll.ID = @GVCD_SourceLanguageLabelID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@GVCD_SourceGridViewDefinitionID BIGINT,
          @GVCD_SourceLanguageLabelID BIGINT,
          @GVCD_GridViewDefinitionGuid UNIQUEIDENTIFIER OUTPUT,
          @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER OUTPUT',
        @GVCD_SourceGridViewDefinitionID = @GVCD_SourceGridViewDefinitionID,
        @GVCD_SourceLanguageLabelID = @GVCD_SourceLanguageLabelID,
        @GVCD_GridViewDefinitionGuid = @GVCD_GridViewDefinitionGuid OUTPUT,
        @GVCD_LanguageLabelGuid = @GVCD_LanguageLabelGuid OUTPUT;

    DECLARE @GridViewColumnDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridViewColumnDefinitionUpsert
        @Name = @GVCD_Name,
        @RowStatus = @GVCD_RowStatus,
        @GridViewDefinitionGuid = @GVCD_GridViewDefinitionGuid,
        @ColumnOrder = @GVCD_ColumnOrder,
        @IsPrimaryKey = @GVCD_IsPrimaryKey,
        @IsHidden = @GVCD_IsHidden,
        @IsFiltered = @GVCD_IsFiltered,
        @IsCombo = @GVCD_IsCombo,
        @DisplayFormat = @GVCD_DisplayFormat,
        @Width = @GVCD_Width,
        @LanguageLabelGuid = @GVCD_LanguageLabelGuid,
        @Guid = @GridViewColumnDefinitionGuid OUTPUT,
        @TopHeaderCategory = @GVCD_TopHeaderCategory,
        @TopHeaderCategoryOrder = @GVCD_TopHeaderCategoryOrder;

    FETCH NEXT FROM GridViewColumnDefinitions_Cursor
    INTO
        @Guid,
        @GVCD_RowStatus,
        @GVCD_Name,
        @GVCD_SourceGridViewDefinitionID,
        @GVCD_ColumnOrder,
        @GVCD_IsPrimaryKey,
        @GVCD_IsHidden,
        @GVCD_IsFiltered,
        @GVCD_IsCombo,
        @GVCD_DisplayFormat,
        @GVCD_Width,
        @GVCD_SourceLanguageLabelID,
        @GVCD_TopHeaderCategory,
        @GVCD_TopHeaderCategoryOrder;
END;

CLOSE GridViewColumnDefinitions_Cursor;
DEALLOCATE GridViewColumnDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewColumnDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view column definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   9. SUserInterface.DropDownListDefinitions
   ========================================================= */

DECLARE
    @DDL_Code NVARCHAR(20),
    @DDL_NameColumn NVARCHAR(254),
    @DDL_ValueColumn NVARCHAR(254),
    @DDL_SqlQuery NVARCHAR(MAX),
    @DDL_DefaultSortColumnName NVARCHAR(254),
    @DDL_IsDefaultColumn BIT,
    @DDL_IsDetailWindowed BIT,
    @DDL_DetailPageURI NVARCHAR(250),
    @DDL_SourceEntityTypeID BIGINT,
    @DDL_InformationPageURI NVARCHAR(250),
    @DDL_GroupColumn NVARCHAR(254),
    @DDL_ColourHexColumn NVARCHAR(7),
    @DDL_ExternalSearchPageUrl NVARCHAR(250),
    @DDL_EntityTypeGuid UNIQUEIDENTIFIER;

DECLARE DropDownListDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.NameColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ValueColumn'),
        ddlJsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultColumn')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
        TRY_CONVERT(BIGINT, JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.InformationPageUrl'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.GroupColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ColourHexColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ExternalSearchPageUrl')
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery'
    ) AS ddlJsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'DropDownListDefinitions'
    ORDER BY sr.SourceRowId;

OPEN DropDownListDefinitions_Cursor;

FETCH NEXT FROM DropDownListDefinitions_Cursor
INTO
    @Guid,
    @DDL_Code,
    @DDL_NameColumn,
    @DDL_ValueColumn,
    @DDL_SqlQuery,
    @DDL_DefaultSortColumnName,
    @DDL_IsDefaultColumn,
    @DDL_IsDetailWindowed,
    @DDL_DetailPageURI,
    @DDL_SourceEntityTypeID,
    @DDL_InformationPageURI,
    @DDL_GroupColumn,
    @DDL_ColourHexColumn,
    @DDL_ExternalSearchPageUrl;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DDL_EntityTypeGuid = NULL;

    SET @Sql = N'
SELECT @DDL_EntityTypeGuid = et.Guid
FROM ' + QUOTENAME(@SourceDatabaseName) + N'.SCore.EntityTypes AS et
WHERE et.ID = @DDL_SourceEntityTypeID;';

    EXEC sys.sp_executesql
        @Sql,
        N'@DDL_SourceEntityTypeID BIGINT,
          @DDL_EntityTypeGuid UNIQUEIDENTIFIER OUTPUT',
        @DDL_SourceEntityTypeID = @DDL_SourceEntityTypeID,
        @DDL_EntityTypeGuid = @DDL_EntityTypeGuid OUTPUT;

    DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.DropDownListDefinitionUpsert
        @Code = @DDL_Code,
        @NameColumn = @DDL_NameColumn,
        @ValueColumn = @DDL_ValueColumn,
        @SqlQuery = @DDL_SqlQuery,
        @DefaultSortColumnName = @DDL_DefaultSortColumnName,
        @IsDefaultColumn = @DDL_IsDefaultColumn,
        @IsDetailWindowed = @DDL_IsDetailWindowed,
        @DetailPageURI = @DDL_DetailPageURI,
        @EntityTypeGuid = @DDL_EntityTypeGuid,
        @InformationPageURI = @DDL_InformationPageURI,
        @GroupColumn = @DDL_GroupColumn,
        @Guid = @DropDownListDefinitionGuid OUTPUT,
        @ColourHexColumn = @DDL_ColourHexColumn,
        @ExternalSearchPageUrl = @DDL_ExternalSearchPageUrl;

    FETCH NEXT FROM DropDownListDefinitions_Cursor
    INTO
        @Guid,
        @DDL_Code,
        @DDL_NameColumn,
        @DDL_ValueColumn,
        @DDL_SqlQuery,
        @DDL_DefaultSortColumnName,
        @DDL_IsDefaultColumn,
        @DDL_IsDetailWindowed,
        @DDL_DetailPageURI,
        @DDL_SourceEntityTypeID,
        @DDL_InformationPageURI,
        @DDL_GroupColumn,
        @DDL_ColourHexColumn,
        @DDL_ExternalSearchPageUrl;
END;

CLOSE DropDownListDefinitions_Cursor;
DEALLOCATE DropDownListDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyDropDownListDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Drop-down list definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   10. Labels
   ========================================================= */

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyLabels',
    @StepStatus = N'Succeeded',
    @Message = N'Labels are applied through SCore.LanguageLabels and SCore.LanguageLabelTranslations handlers.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations"]}';

UPDATE SMigration.Metadata_Run
SET
    RunStatus = N'AppliedUiMetadata',
    AppliedOnUtc = SYSUTCDATETIME()
WHERE Guid = @RunGuid
  AND RowStatus NOT IN (0,254);

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyMetadataComplete',
    @StepStatus = N'Succeeded',
    @Message = N'Core and UI metadata apply handlers completed.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations","SCore.EntityQueries","SCore.EntityProperties","SCore.EntityQueryParameters","SUserInterface.GridDefinitions","SUserInterface.GridViewDefinitions","SUserInterface.GridViewColumnDefinitions","SUserInterface.DropDownListDefinitions"]}';

COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApplyIdentityMap_Build]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @TargetDatabaseName SYSNAME,
        @SchemaName SYSNAME,
        @TableName SYSNAME,
        @GuidColumnName SYSNAME,
        @PrimaryKeyColumnName SYSNAME,
        @RegistryGuid UNIQUEIDENTIFIER,
        @Sql NVARCHAR(MAX);

    SELECT
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @TargetDatabaseName IS NULL
    BEGIN
        ;THROW 51000, 'Metadata run was not found or is inactive.', 1;
    END;

    BEGIN TRANSACTION;

    DELETE FROM SMigration.Metadata_ApplyIdentityMap
    WHERE RunGuid = @RunGuid;

    INSERT INTO SMigration.Metadata_ApplyIdentityMap
    (
        Guid,
        RowStatus,
        RunGuid,
        RegistryGuid,
        SchemaName,
        TableName,
        SourceRowGuid,
        SourceRowId,
        TargetRowId,
        CreatedOnUtc
    )
    SELECT
        NEWID(),
        1,
        sr.RunGuid,
        sr.RegistryGuid,
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowGuid,
        sr.SourceRowId,
        NULL,
        SYSUTCDATETIME()
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update');

    DECLARE registry_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            tr.Guid,
            tr.SchemaName,
            tr.TableName,
            tr.GuidColumnName,
            tr.PrimaryKeyColumnName
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
        ORDER BY
            tr.ApplyOrder,
            tr.SchemaName,
            tr.TableName;

    OPEN registry_cursor;

    FETCH NEXT FROM registry_cursor
    INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @Sql = N'
UPDATE maprow
SET
    maprow.TargetRowId = TRY_CONVERT(BIGINT, targetrow.' + QUOTENAME(@PrimaryKeyColumnName) + N')
FROM SMigration.Metadata_ApplyIdentityMap AS maprow
INNER JOIN ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS targetrow
    ON targetrow.' + QUOTENAME(@GuidColumnName) + N' = maprow.SourceRowGuid
WHERE maprow.RunGuid = @RunGuid
  AND maprow.RegistryGuid = @RegistryGuid
  AND maprow.RowStatus NOT IN (0,254);';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid,
            @RegistryGuid = @RegistryGuid;

        FETCH NEXT FROM registry_cursor
        INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;
    END;

    CLOSE registry_cursor;
    DEALLOCATE registry_cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'BuildIdentityMap',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata apply identity map built.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;

    SELECT
        SchemaName,
        TableName,
        COUNT_BIG(1) AS MapRows,
        SUM(CASE WHEN TargetRowId IS NULL THEN 1 ELSE 0 END) AS MissingTargetRows
    FROM SMigration.Metadata_ApplyIdentityMap
    WHERE RunGuid = @RunGuid
      AND RowStatus NOT IN (0,254)
    GROUP BY
        SchemaName,
        TableName
    ORDER BY
        SchemaName,
        TableName;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataDataObject_Ensure]
(
    @Guid       UNIQUEIDENTIFIER,
    @SchemeName NVARCHAR(255),
    @ObjectName NVARCHAR(255)
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @EntityTypeId INT = NULL;

    SELECT TOP (1)
        @EntityTypeId = et.ID
    FROM SCore.EntityHobts AS eh
    INNER JOIN SCore.EntityTypes AS et
        ON et.ID = eh.EntityTypeID
    WHERE eh.SchemaName = @SchemeName
      AND eh.ObjectName = @ObjectName
      AND eh.RowStatus NOT IN (0,254)
      AND et.RowStatus NOT IN (0,254)
    ORDER BY et.ID;

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = et.ID
        FROM SCore.EntityTypes AS et
        WHERE et.Name = N'EntityTypes'
          AND et.RowStatus NOT IN (0,254)
        ORDER BY et.ID;
    END;

    IF @EntityTypeId IS NULL
    BEGIN
        SELECT TOP (1)
            @EntityTypeId = et.ID
        FROM SCore.EntityTypes AS et
        WHERE et.RowStatus NOT IN (0,254)
        ORDER BY et.ID;
    END;

    IF @EntityTypeId IS NULL
    BEGIN
        ;THROW 51010, 'No active SCore.EntityTypes row exists to support DataObjects creation.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SCore.DataObjects AS d
        WHERE d.Guid = @Guid
    )
    BEGIN
        INSERT INTO SCore.DataObjects
        (
            Guid,
            RowStatus,
            EntityTypeId
        )
        SELECT
            @Guid,
            1,
            @EntityTypeId;
    END
    ELSE
    BEGIN
        UPDATE SCore.DataObjects
        SET
            RowStatus = CASE WHEN RowStatus IN (0,254) THEN 1 ELSE RowStatus END,
            EntityTypeId = ISNULL(EntityTypeId, @EntityTypeId)
        WHERE Guid = @Guid;
    END;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataExecutionLog_Add]
(
    @RunGuid     UNIQUEIDENTIFIER,
    @StepName    NVARCHAR(100),
    @StepStatus  NVARCHAR(30),
    @Message     NVARCHAR(2000) = N'',
    @DetailsJson NVARCHAR(MAX) = N'{}'
)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @LogGuid UNIQUEIDENTIFIER = NEWID();

    EXEC SMigration.MetadataDataObject_Ensure
        @Guid = @LogGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Metadata_ExecutionLog';

    INSERT INTO SMigration.Metadata_ExecutionLog
    (
        Guid,
        RowStatus,
        RunGuid,
        StepName,
        StepStatus,
        Message,
        DetailsJson,
        CreatedOnUtc
    )
    SELECT
        @LogGuid,
        1,
        @RunGuid,
        @StepName,
        @StepStatus,
        ISNULL(@Message, N''),
        ISNULL(@DetailsJson, N'{}'),
        SYSUTCDATETIME();
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRegistry_Seed]
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

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRun_Create]
(
    @SourceEnvironment NVARCHAR(20),
    @TargetEnvironment NVARCHAR(20),
    @SourceServerName NVARCHAR(255),
    @SourceDatabaseName NVARCHAR(255),
    @TargetServerName NVARCHAR(255),
    @TargetDatabaseName NVARCHAR(255),
    @IsValidateOnly BIT = 1,
    @RunGuid UNIQUEIDENTIFIER OUTPUT
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    SET @RunGuid = ISNULL(NULLIF(@RunGuid, '00000000-0000-0000-0000-000000000000'), NEWID());

    BEGIN TRANSACTION;

    EXEC SMigration.MetadataDataObject_Ensure
        @Guid = @RunGuid,
        @SchemeName = N'SMigration',
        @ObjectName = N'Metadata_Run';

    INSERT INTO SMigration.Metadata_Run
    (
        Guid,
        RowStatus,
        SourceEnvironment,
        TargetEnvironment,
        SourceServerName,
        SourceDatabaseName,
        TargetServerName,
        TargetDatabaseName,
        RunStatus,
        IsValidateOnly,
        CreatedOnUtc,
        CreatedByUserId,
        SummaryJson
    )
    SELECT
        @RunGuid,
        1,
        @SourceEnvironment,
        @TargetEnvironment,
        @SourceServerName,
        @SourceDatabaseName,
        @TargetServerName,
        @TargetDatabaseName,
        N'Created',
        ISNULL(@IsValidateOnly, 1),
        SYSUTCDATETIME(),
        ISNULL(SCore.GetCurrentUserId(), -1),
        N'{}'
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
    );

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'CreateRun',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata migration run created.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRun_Get]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        r.ID,
        r.Guid,
        r.RowStatus,
        r.SourceEnvironment,
        r.TargetEnvironment,
        r.SourceServerName,
        r.SourceDatabaseName,
        r.TargetServerName,
        r.TargetDatabaseName,
        r.RunStatus,
        r.IsValidateOnly,
        r.CreatedOnUtc,
        r.ValidatedOnUtc,
        r.AppliedOnUtc,
        r.CreatedByUserId,
        r.SummaryJson
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    SELECT
        sr.ID,
        sr.Guid,
        sr.RowStatus,
        sr.RunGuid,
        sr.RegistryGuid,
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowGuid,
        sr.SourceRowId,
        sr.SourceRowStatus,
        sr.DifferenceType,
        sr.CreatedOnUtc
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
    ORDER BY tr.ApplyOrder, tr.SchemaName, tr.TableName, sr.ID;

    SELECT
        vi.ID,
        vi.Guid,
        vi.RowStatus,
        vi.RunGuid,
        vi.RegistryGuid,
        tr.SchemaName,
        tr.TableName,
        vi.SourceRowGuid,
        vi.Severity,
        vi.IssueCode,
        vi.IssueMessage,
        vi.DetailsJson,
        vi.CreatedOnUtc
    FROM SMigration.Metadata_ValidationIssues AS vi
    LEFT JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = vi.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
    ORDER BY vi.ID;

    SELECT
        el.ID,
        el.Guid,
        el.RowStatus,
        el.RunGuid,
        el.StepName,
        el.StepStatus,
        el.Message,
        el.DetailsJson,
        el.CreatedOnUtc
    FROM SMigration.Metadata_ExecutionLog AS el
    WHERE el.RunGuid = @RunGuid
      AND el.RowStatus NOT IN (0,254)
    ORDER BY el.ID;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRun_List]
(
    @Top INT = 100,
    @SourceEnvironment NVARCHAR(20) = NULL,
    @TargetEnvironment NVARCHAR(20) = NULL,
    @RunStatus NVARCHAR(30) = NULL
)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT TOP (ISNULL(@Top, 100))
        r.ID,
        r.Guid,
        r.RowStatus,
        r.SourceEnvironment,
        r.TargetEnvironment,
        r.SourceServerName,
        r.SourceDatabaseName,
        r.TargetServerName,
        r.TargetDatabaseName,
        r.RunStatus,
        r.IsValidateOnly,
        r.CreatedOnUtc,
        r.ValidatedOnUtc,
        r.AppliedOnUtc,
        r.CreatedByUserId,
        r.SummaryJson
    FROM SMigration.Metadata_Run AS r
    WHERE r.RowStatus NOT IN (0,254)
      AND (@SourceEnvironment IS NULL OR r.SourceEnvironment = @SourceEnvironment)
      AND (@TargetEnvironment IS NULL OR r.TargetEnvironment = @TargetEnvironment)
      AND (@RunStatus IS NULL OR r.RunStatus = @RunStatus)
    ORDER BY r.ID DESC;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataStage_Run]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @SourceDatabaseName SYSNAME,
        @TargetDatabaseName SYSNAME,
        @SchemaName SYSNAME,
        @TableName SYSNAME,
        @GuidColumnName SYSNAME,
        @PrimaryKeyColumnName SYSNAME,
        @RegistryGuid UNIQUEIDENTIFIER,
        @ColumnList NVARCHAR(MAX),
        @HasRowStatus BIT,
        @SourceWhereClause NVARCHAR(MAX),
        @SourceAndClause NVARCHAR(MAX),
        @DuplicateWhereClause NVARCHAR(MAX),
        @SourceRowStatusExpression NVARCHAR(MAX),
        @Sql NVARCHAR(MAX);

    SELECT
        @SourceDatabaseName = r.SourceDatabaseName,
        @TargetDatabaseName = r.TargetDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @SourceDatabaseName IS NULL
    BEGIN
        ;THROW 51000, 'Metadata run was not found or is inactive.', 1;
    END;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
    )
    BEGIN
        ;THROW 51001, 'No enabled metadata registry rows exist. Run SMigration.MetadataRegistry_Seed first.', 1;
    END;

    BEGIN TRANSACTION;

    DELETE FROM SMigration.Metadata_StagedRows
    WHERE RunGuid = @RunGuid;

    DELETE FROM SMigration.Metadata_ValidationIssues
    WHERE RunGuid = @RunGuid
      AND IssueCode IN
      (
          N'DuplicateSourceGuid',
          N'RegisteredGuidColumnMissing',
          N'RegisteredTableMissing'
      );

    DECLARE registry_cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            tr.Guid,
            tr.SchemaName,
            tr.TableName,
            tr.GuidColumnName,
            tr.PrimaryKeyColumnName
        FROM SMigration.Metadata_TableRegistry AS tr
        WHERE tr.RowStatus NOT IN (0,254)
          AND tr.IsEnabled = 1
        ORDER BY
            tr.ApplyOrder,
            tr.SchemaName,
            tr.TableName;

    OPEN registry_cursor;

    FETCH NEXT FROM registry_cursor
    INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ColumnList = NULL;
        SET @HasRowStatus = 0;
        SET @Sql = NULL;

        IF OBJECT_ID(QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName), N'U') IS NULL
        BEGIN
            INSERT INTO SMigration.Metadata_ValidationIssues
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                Severity,
                IssueCode,
                IssueMessage,
                DetailsJson,
                CreatedOnUtc
            )
            SELECT
                NEWID(),
                1,
                @RunGuid,
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredTableMissing',
                CONCAT(N'Registered metadata table does not exist in target: ', @SchemaName, N'.', @TableName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        IF NOT EXISTS
        (
            SELECT 1
            FROM sys.schemas AS s
            INNER JOIN sys.tables AS t
                ON t.schema_id = s.schema_id
            INNER JOIN sys.columns AS c
                ON c.object_id = t.object_id
            WHERE s.name = @SchemaName
              AND t.name = @TableName
              AND c.name = @GuidColumnName
        )
        BEGIN
            INSERT INTO SMigration.Metadata_ValidationIssues
            (
                Guid,
                RowStatus,
                RunGuid,
                RegistryGuid,
                SourceRowGuid,
                Severity,
                IssueCode,
                IssueMessage,
                DetailsJson,
                CreatedOnUtc
            )
            SELECT
                NEWID(),
                1,
                @RunGuid,
                @RegistryGuid,
                NULL,
                N'Fail',
                N'RegisteredGuidColumnMissing',
                CONCAT(N'Registered metadata table does not have Guid column: ', @SchemaName, N'.', @TableName, N'.', @GuidColumnName),
                CONCAT(N'{"SchemaName":"', @SchemaName, N'","TableName":"', @TableName, N'","GuidColumnName":"', @GuidColumnName, N'"}'),
                SYSUTCDATETIME();

            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        SELECT
            @HasRowStatus =
                CASE WHEN EXISTS
                (
                    SELECT 1
                    FROM sys.schemas AS s
                    INNER JOIN sys.tables AS t
                        ON t.schema_id = s.schema_id
                    INNER JOIN sys.columns AS c
                        ON c.object_id = t.object_id
                    WHERE s.name = @SchemaName
                      AND t.name = @TableName
                      AND c.name = N'RowStatus'
                )
                THEN 1 ELSE 0 END;

        SELECT
            @ColumnList =
                STRING_AGG(CONVERT(NVARCHAR(MAX), QUOTENAME(c.name)), N',')
                WITHIN GROUP (ORDER BY c.column_id)
        FROM sys.schemas AS s
        INNER JOIN sys.tables AS t
            ON t.schema_id = s.schema_id
        INNER JOIN sys.columns AS c
            ON c.object_id = t.object_id
        WHERE s.name = @SchemaName
          AND t.name = @TableName
          AND c.is_computed = 0
          AND c.system_type_id <> 189;

        IF @ColumnList IS NULL
        BEGIN
            FETCH NEXT FROM registry_cursor
            INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;

            CONTINUE;
        END;

        SET @SourceRowStatusExpression =
            CASE WHEN @HasRowStatus = 1
                THEN N'TRY_CONVERT(TINYINT, s.RowStatus)'
                ELSE N'NULL'
            END;

        SET @SourceWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE s.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @SourceAndClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'AND'
                ELSE N'WHERE'
            END;

        SET @DuplicateWhereClause =
            CASE WHEN @HasRowStatus = 1
                THEN N'WHERE sd.RowStatus NOT IN (0,254)'
                ELSE N''
            END;

        SET @Sql = N'
INSERT INTO SMigration.Metadata_ValidationIssues
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    Severity,
    IssueCode,
    IssueMessage,
    DetailsJson,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    d.SourceRowGuid,
    N''Fail'',
    N''DuplicateSourceGuid'',
    CONCAT(N''Source metadata table contains duplicate active Guid values: ' + REPLACE(@SchemaName, '''', '''''') + N'.' + REPLACE(@TableName, '''', '''''') + N' / '', CONVERT(NVARCHAR(36), d.SourceRowGuid)),
    CONCAT
    (
        N''{"SchemaName":"' + REPLACE(@SchemaName, '''', '''''') + N'","TableName":"' + REPLACE(@TableName, '''', '''''') + N'","DuplicateCount":'',
        CONVERT(NVARCHAR(30), d.DuplicateCount),
        N''}''
    ),
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        COUNT_BIG(1) AS DuplicateCount
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    ' + @SourceWhereClause + N'
    GROUP BY CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    HAVING COUNT_BIG(1) > 1
) AS d;

INSERT INTO SMigration.Metadata_StagedRows
(
    Guid,
    RowStatus,
    RunGuid,
    RegistryGuid,
    SourceRowGuid,
    SourceRowId,
    SourceRowStatus,
    SourcePayloadJson,
    SourcePayloadHash,
    TargetPayloadJson,
    TargetPayloadHash,
    DifferenceType,
    CreatedOnUtc
)
SELECT
    NEWID(),
    1,
    @RunGuid,
    @RegistryGuid,
    src.SourceRowGuid,
    src.SourceRowId,
    src.SourceRowStatus,
    src.SourcePayloadJson,
    HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), src.SourcePayloadJson)),
    tgt.TargetPayloadJson,
    CASE
        WHEN tgt.TargetPayloadJson IS NULL THEN NULL
        ELSE HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson))
    END,
    CASE
        WHEN tgt.TargetPayloadJson IS NULL THEN N''Insert''
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), src.SourcePayloadJson))
           <> HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''Update''
        ELSE N''NoChange''
    END,
    SYSUTCDATETIME()
FROM
(
    SELECT
        CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N') AS SourceRowGuid,
        TRY_CONVERT(BIGINT, s.' + QUOTENAME(@PrimaryKeyColumnName) + N') AS SourceRowId,
        ' + @SourceRowStatusExpression + N' AS SourceRowStatus,
        (
            SELECT ' + @ColumnList + N'
            FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS sj
            WHERE sj.' + QUOTENAME(@GuidColumnName) + N' = s.' + QUOTENAME(@GuidColumnName) + N'
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS SourcePayloadJson
    FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS s
    ' + @SourceWhereClause + N'
    ' + @SourceAndClause + N' NOT EXISTS
    (
        SELECT 1
        FROM
        (
            SELECT
                CONVERT(UNIQUEIDENTIFIER, sd.' + QUOTENAME(@GuidColumnName) + N') AS DuplicateGuid
            FROM ' + QUOTENAME(@SourceDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS sd
            ' + @DuplicateWhereClause + N'
            GROUP BY CONVERT(UNIQUEIDENTIFIER, sd.' + QUOTENAME(@GuidColumnName) + N')
            HAVING COUNT_BIG(1) > 1
        ) AS dup
        WHERE dup.DuplicateGuid = CONVERT(UNIQUEIDENTIFIER, s.' + QUOTENAME(@GuidColumnName) + N')
    )
) AS src
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @ColumnList + N'
            FROM ' + QUOTENAME(@TargetDatabaseName) + N'.' + QUOTENAME(@SchemaName) + N'.' + QUOTENAME(@TableName) + N' AS tj
            WHERE tj.' + QUOTENAME(@GuidColumnName) + N' = src.SourceRowGuid
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER, @RegistryGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid,
            @RegistryGuid = @RegistryGuid;

        FETCH NEXT FROM registry_cursor
        INTO @RegistryGuid, @SchemaName, @TableName, @GuidColumnName, @PrimaryKeyColumnName;
    END;

    CLOSE registry_cursor;
    DEALLOCATE registry_cursor;

    EXEC SMigration.MetadataStage_NormaliseDifferences
        @RunGuid = @RunGuid;

    EXEC SMigration.MetadataStage_NormaliseEnvironmentOnlyUpdates
        @RunGuid = @RunGuid;

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = N'Staged',
        SummaryJson =
        (
            SELECT
                CONCAT
                (
                    N'{"insertCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Insert' THEN 1 ELSE 0 END), 0)),
                    N',"updateCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Update' THEN 1 ELSE 0 END), 0)),
                    N',"noChangeCount":',
                    CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'NoChange' THEN 1 ELSE 0 END), 0)),
                    N',"totalCount":',
                    CONVERT(NVARCHAR(30), COUNT_BIG(1)),
                    N'}'
                )
            FROM SMigration.Metadata_StagedRows AS sr
            WHERE sr.RunGuid = @RunGuid
              AND sr.RowStatus NOT IN (0,254)
        )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'StageRun',
        @StepStatus = N'Succeeded',
        @Message = N'Metadata staging completed.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;
END;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataValidate_Run]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE @FailCount INT = 0;
    DECLARE @WarnCount INT = 0;
    DECLARE @InfoCount INT = 0;

    BEGIN TRANSACTION;

    -- Only clear validation issues owned by this validation proc.
    -- Do NOT delete staging-discovered blockers such as DuplicateSourceGuid.
    DELETE FROM SMigration.Metadata_ValidationIssues
    WHERE RunGuid = @RunGuid
      AND IssueCode IN
      (
          N'RunNotFound',
          N'DuplicateStagedRow'
      );

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
          AND r.RowStatus NOT IN (0,254)
    )
    BEGIN
        INSERT INTO SMigration.Metadata_ValidationIssues
        (
            Guid,
            RowStatus,
            RunGuid,
            RegistryGuid,
            SourceRowGuid,
            Severity,
            IssueCode,
            IssueMessage,
            DetailsJson,
            CreatedOnUtc
        )
        SELECT
            NEWID(),
            1,
            @RunGuid,
            NULL,
            NULL,
            N'Fail',
            N'RunNotFound',
            N'Metadata migration run does not exist or is inactive.',
            N'{}',
            SYSUTCDATETIME();
    END;

    INSERT INTO SMigration.Metadata_ValidationIssues
    (
        Guid,
        RowStatus,
        RunGuid,
        RegistryGuid,
        SourceRowGuid,
        Severity,
        IssueCode,
        IssueMessage,
        DetailsJson,
        CreatedOnUtc
    )
    SELECT
        NEWID(),
        1,
        @RunGuid,
        sr.RegistryGuid,
        sr.SourceRowGuid,
        N'Fail',
        N'DuplicateStagedRow',
        N'The staged run contains duplicate rows for the same table and source row Guid.',
        CONCAT(N'{"SourceRowGuid":"', CONVERT(NVARCHAR(36), sr.SourceRowGuid), N'"}'),
        SYSUTCDATETIME()
    FROM SMigration.Metadata_StagedRows AS sr
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
    GROUP BY
        sr.RegistryGuid,
        sr.SourceRowGuid
    HAVING COUNT_BIG(1) > 1;

    SELECT
        @FailCount = SUM(CASE WHEN vi.Severity = N'Fail' THEN 1 ELSE 0 END),
        @WarnCount = SUM(CASE WHEN vi.Severity = N'Warn' THEN 1 ELSE 0 END),
        @InfoCount = SUM(CASE WHEN vi.Severity = N'Info' THEN 1 ELSE 0 END)
    FROM SMigration.Metadata_ValidationIssues AS vi
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254);

    SET @FailCount = ISNULL(@FailCount, 0);
    SET @WarnCount = ISNULL(@WarnCount, 0);
    SET @InfoCount = ISNULL(@InfoCount, 0);

    UPDATE SMigration.Metadata_Run
    SET
        RunStatus = CASE WHEN @FailCount > 0 THEN N'ValidationFailed' ELSE N'Validated' END,
        ValidatedOnUtc = SYSUTCDATETIME(),
        SummaryJson = CONCAT
        (
            N'{"failCount":',
            CONVERT(NVARCHAR(30), @FailCount),
            N',"warnCount":',
            CONVERT(NVARCHAR(30), @WarnCount),
            N',"infoCount":',
            CONVERT(NVARCHAR(30), @InfoCount),
            N'}'
        )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);
    DECLARE @_StepStatus AS NVARCHAR(15) = (CASE WHEN @FailCount > 0 THEN N'Failed' ELSE N'Succeeded' END)
    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ValidateRun',
        @StepStatus = @_StepStatus,
        @Message = N'Metadata migration validation completed.',
        @DetailsJson = N'{}';

    COMMIT TRANSACTION;

    SELECT
        @FailCount AS FailCount,
        @WarnCount AS WarnCount,
        @InfoCount AS InfoCount;
END;
GO



/* ================================================================================================
   Latest metadata apply and stage/diff normalisation handlers
   ================================================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApply_Run]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ForceApply BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RunStatus NVARCHAR(30),
        @TargetEnvironment NVARCHAR(20),
        @SourceDatabaseName SYSNAME,
        @FailCount INT = 0,
        @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    SELECT
        @RunStatus = r.RunStatus,
        @TargetEnvironment = r.TargetEnvironment,
        @SourceDatabaseName = r.SourceDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @RunStatus IS NULL
        THROW 52000, 'Metadata run was not found or is inactive.', 1;

    IF @RunStatus NOT IN
    (
        N'Validated',
        N'PartiallyApplied',
        N'AppliedCoreMetadata',
        N'AppliedUiMetadata'
    )
        THROW 52001, 'Metadata run must be Validated, PartiallyApplied, AppliedCoreMetadata or AppliedUiMetadata before apply.', 1;

    SELECT
        @FailCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi
    INNER JOIN SMigration.Metadata_Run AS runScope
        ON runScope.Guid = vi.RunGuid
       AND runScope.RowStatus NOT IN (0,254)
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored
          WHERE ignored.DatabaseName = runScope.TargetDatabaseName
            AND ignored.RegistryGuid = vi.RegistryGuid
            AND ignored.SourceRowGuid = vi.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      );

    IF ISNULL(@FailCount, 0) > 0
        THROW 52002, 'Metadata run has validation failures and cannot be applied.', 1;

    IF @TargetEnvironment = N'LIVE' AND ISNULL(@ForceApply, 0) = 0
        THROW 52003, 'LIVE metadata apply requires @ForceApply = 1.', 1;

    BEGIN TRANSACTION;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyStart',
        @StepStatus = N'Started',
        @Message = N'Metadata apply started.',
        @DetailsJson = N'{}';

    
    IF OBJECT_ID(N'tempdb..#MetadataSourceGuidLookup') IS NOT NULL
        DROP TABLE #MetadataSourceGuidLookup;

    CREATE TABLE #MetadataSourceGuidLookup
    (
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        SourceRowId BIGINT NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_MetadataSourceGuidLookup PRIMARY KEY CLUSTERED
        (
            SchemaName,
            TableName,
            SourceRowId
        )
    );

    INSERT INTO #MetadataSourceGuidLookup
    (
        SchemaName,
        TableName,
        SourceRowId,
        SourceRowGuid
    )
    SELECT
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowId,
        sr.SourceRowGuid
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.SourceRowId IS NOT NULL
      AND sr.SourceRowGuid IS NOT NULL;
/* =========================================================
       1. SCore.LanguageLabels
       ========================================================= */
    DECLARE
        @Guid UNIQUEIDENTIFIER,
        @Name NVARCHAR(500);

    DECLARE LanguageLabels_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name')
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'LanguageLabels'
        ORDER BY sr.SourceRowId;

    OPEN LanguageLabels_Cursor;

    FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelUpsert
            @Name = @Name,
            @Guid = @LanguageLabelGuid OUTPUT;

        FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;
    END;

    CLOSE LanguageLabels_Cursor;
    DEALLOCATE LanguageLabels_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabels',
        @StepStatus = N'Succeeded',
        @Message = N'Language labels applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       2. SCore.LanguageLabelTranslations
       ========================================================= */
    DECLARE
        @Text NVARCHAR(500),
        @TextPlural NVARCHAR(500),
        @HelpText NVARCHAR(MAX),
        @LanguageLabelGuidRef UNIQUEIDENTIFIER,
        @LanguageGuidRef UNIQUEIDENTIFIER,
        @SourceLanguageLabelId BIGINT,
        @SourceLanguageId BIGINT,
        @Sql NVARCHAR(MAX);

    IF OBJECT_ID(N'tempdb..#LanguageLabelTranslationsToApply') IS NOT NULL
        DROP TABLE #LanguageLabelTranslationsToApply;

    CREATE TABLE #LanguageLabelTranslationsToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        Text NVARCHAR(500) NULL,
        TextPlural NVARCHAR(500) NULL,
        HelpText NVARCHAR(MAX) NULL,
        SourceLanguageLabelId BIGINT NULL,
        SourceLanguageId BIGINT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #LanguageLabelTranslationsToApply
    (
        Guid,
        Text,
        TextPlural,
        HelpText,
        SourceLanguageLabelId,
        SourceLanguageId,
        SourceRowId
    )
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Text'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TextPlural'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.HelpText'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageId'))),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'LanguageLabelTranslations';

    DECLARE LanguageLabelTranslations_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            Text,
            TextPlural,
            HelpText,
            SourceLanguageLabelId,
            SourceLanguageId
        FROM #LanguageLabelTranslationsToApply
        ORDER BY SourceRowId;

    OPEN LanguageLabelTranslations_Cursor;

    FETCH NEXT FROM LanguageLabelTranslations_Cursor
    INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @LanguageLabelGuidRef = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'LanguageLabels'
          AND lookup.SourceRowId = @SourceLanguageLabelId;

        SELECT
            @LanguageGuidRef = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'Languages'
          AND lookup.SourceRowId = @SourceLanguageId;

        DECLARE @LanguageLabelTranslationGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelTranslationUpsert
            @Text = @Text,
            @TextPlural = @TextPlural,
            @HelpText = @HelpText,
            @LanguageLabelGuid = @LanguageLabelGuidRef,
            @LanguageGuid = @LanguageGuidRef,
            @Guid = @LanguageLabelTranslationGuid OUTPUT;

        FETCH NEXT FROM LanguageLabelTranslations_Cursor
        INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;
    END;

    CLOSE LanguageLabelTranslations_Cursor;
    DEALLOCATE LanguageLabelTranslations_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabelTranslations',
        @StepStatus = N'Succeeded',
        @Message = N'Language label translations applied.',
        @DetailsJson = N'{}';


    
/* =========================================================
       3. SCore.EntityDataTypes
       Required reference metadata for EntityProperties and EntityQueryParameters.
       No dedicated EntityDataTypeUpsert exists in the current schema, so this
       handler uses SCore.UpsertDataObject and explicit idempotent DML.
       ========================================================= */
    DECLARE
        @EDT_RowStatus TINYINT,
        @EDT_Name NVARCHAR(250),
        @EDT_QuoteValue BIT,
        @EDT_IsInsert BIT;

    DECLARE EntityDataTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.QuoteValue'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityDataTypes'
        ORDER BY sr.SourceRowId;

    OPEN EntityDataTypes_Cursor;

    FETCH NEXT FROM EntityDataTypes_Cursor
    INTO
        @Guid,
        @EDT_RowStatus,
        @EDT_Name,
        @EDT_QuoteValue;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EDT_IsInsert = 0;

        EXEC SCore.UpsertDataObject
            @Guid = @Guid,
            @SchemeName = N'SCore',
            @ObjectName = N'EntityDataTypes',
            @IsInsert = @EDT_IsInsert OUTPUT;

        IF @EDT_IsInsert = 1
        BEGIN
            INSERT INTO SCore.EntityDataTypes
            (
                Guid,
                RowStatus,
                Name,
                QuoteValue
            )
            VALUES
            (
                @Guid,
                ISNULL(NULLIF(@EDT_RowStatus, 0), 1),
                ISNULL(@EDT_Name, N''),
                ISNULL(@EDT_QuoteValue, 0)
            );
        END;
        ELSE
        BEGIN
            UPDATE SCore.EntityDataTypes
            SET
                RowStatus = ISNULL(NULLIF(@EDT_RowStatus, 0), RowStatus),
                Name = ISNULL(@EDT_Name, N''),
                QuoteValue = ISNULL(@EDT_QuoteValue, 0)
            WHERE Guid = @Guid;
        END;

        FETCH NEXT FROM EntityDataTypes_Cursor
        INTO
            @Guid,
            @EDT_RowStatus,
            @EDT_Name,
            @EDT_QuoteValue;
    END;

    CLOSE EntityDataTypes_Cursor;
    DEALLOCATE EntityDataTypes_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityDataTypes',
        @StepStatus = N'Succeeded',
        @Message = N'Entity data types applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       4. SUserInterface.Icons
       Required reference metadata for EntityTypes and GridViewDefinitions.
       No dedicated IconUpsert exists in the current schema, so this
       handler uses SCore.UpsertDataObject and explicit idempotent DML.
       Natural key fallback is Name to avoid duplicate icon CSS classes.
       ========================================================= */
    DECLARE
        @ICON_RowStatus TINYINT,
        @ICON_Name NVARCHAR(50),
        @ICON_SourceRowId BIGINT,
        @ICON_IsInsert BIT,
        @ICON_ExistingGuid UNIQUEIDENTIFIER,
        @ICON_GuidToApply UNIQUEIDENTIFIER;

    DECLARE Icons_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            sr.SourceRowId
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SUserInterface'
          AND tr.TableName = N'Icons'
        ORDER BY sr.SourceRowId;

    OPEN Icons_Cursor;

    FETCH NEXT FROM Icons_Cursor
    INTO
        @Guid,
        @ICON_RowStatus,
        @ICON_Name,
        @ICON_SourceRowId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ICON_ExistingGuid = NULL;
        SET @ICON_GuidToApply = @Guid;
        SET @ICON_IsInsert = 0;

        SELECT TOP (1)
            @ICON_ExistingGuid = i.Guid
        FROM SUserInterface.Icons AS i
        WHERE i.Name = ISNULL(@ICON_Name, N'')
          AND i.RowStatus NOT IN (0,254)
          AND i.Guid <> @Guid
        ORDER BY i.ID;

        IF @ICON_ExistingGuid IS NOT NULL
        BEGIN
            SET @ICON_GuidToApply = @ICON_ExistingGuid;

            UPDATE lookup
            SET SourceRowGuid = @ICON_ExistingGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SUserInterface'
              AND lookup.TableName = N'Icons'
              AND lookup.SourceRowId = @ICON_SourceRowId;
        END;

        EXEC SCore.UpsertDataObject
            @Guid = @ICON_GuidToApply,
            @SchemeName = N'SUserInterface',
            @ObjectName = N'Icons',
            @IsInsert = @ICON_IsInsert OUTPUT;

        IF @ICON_IsInsert = 1
        BEGIN
            INSERT INTO SUserInterface.Icons
            (
                Guid,
                RowStatus,
                Name
            )
            VALUES
            (
                @ICON_GuidToApply,
                ISNULL(NULLIF(@ICON_RowStatus, 0), 1),
                ISNULL(@ICON_Name, N'')
            );
        END;
        ELSE
        BEGIN
            UPDATE SUserInterface.Icons
            SET
                RowStatus = ISNULL(NULLIF(@ICON_RowStatus, 0), RowStatus),
                Name = ISNULL(@ICON_Name, N'')
            WHERE Guid = @ICON_GuidToApply;
        END;

        FETCH NEXT FROM Icons_Cursor
        INTO
            @Guid,
            @ICON_RowStatus,
            @ICON_Name,
            @ICON_SourceRowId;
    END;

    CLOSE Icons_Cursor;
    DEALLOCATE Icons_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyIcons',
        @StepStatus = N'Succeeded',
        @Message = N'Icons applied.',
        @DetailsJson = N'{}';


/* =========================================================
       3. SCore.EntityTypes
       Required reference metadata for EntityQueries/GridViews/DropDownLists.
       Applies staged EntityTypes before dependent metadata.
       ========================================================= */
    DECLARE
        @ET_RowStatus TINYINT,
        @ET_IsReadOnlyOffline BIT,
        @ET_IsRequiredSystemData BIT,
        @ET_HasDocuments BIT,
        @ET_SourceLanguageLabelID BIGINT,
        @ET_DoNotTrackChanges BIT,
        @ET_SourceIconID BIGINT,
        @ET_IsRootEntity BIT,
        @ET_DetailPageUrl NVARCHAR(250),
        @ET_IsMetaData BIT,
        @ET_IsDeletable BIT,
        @ET_LanguageLabelGuid UNIQUEIDENTIFIER,
        @ET_IconGuid UNIQUEIDENTIFIER;

    DECLARE EntityTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsRequiredSystemData')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasDocuments')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.IconID'), JSON_VALUE(sr.SourcePayloadJson, N'$.IconId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsRootEntity')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMetaData')),
            ISNULL(TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDeletable')), 1)
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityTypes'
        ORDER BY sr.SourceRowId;

    OPEN EntityTypes_Cursor;

    FETCH NEXT FROM EntityTypes_Cursor
    INTO
        @Guid,
        @ET_RowStatus,
        @Name,
        @ET_IsReadOnlyOffline,
        @ET_IsRequiredSystemData,
        @ET_HasDocuments,
        @ET_SourceLanguageLabelID,
        @ET_DoNotTrackChanges,
        @ET_SourceIconID,
        @ET_IsRootEntity,
        @ET_DetailPageUrl,
            @ET_IsMetaData,
            @ET_IsDeletable;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ET_LanguageLabelGuid = NULL;
        SET @ET_IconGuid = NULL;

        SELECT
            @ET_LanguageLabelGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'LanguageLabels'
          AND lookup.SourceRowId = @ET_SourceLanguageLabelID;

        SELECT
            @ET_IconGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'Icons'
          AND lookup.SourceRowId = @ET_SourceIconID;

        DECLARE @EntityTypeGuidToApply UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityTypeUpsert
            @Name = @Name,
            @RowStatus = @ET_RowStatus,
            @IsReadOnlyOffline = @ET_IsReadOnlyOffline,
            @IsRequiredSystemData = @ET_IsRequiredSystemData,
            @HasDocuments = @ET_HasDocuments,
            @LanguageLabelGuid = @ET_LanguageLabelGuid,
            @DoNotTrackChanges = @ET_DoNotTrackChanges,
            @IconGuid = @ET_IconGuid,
            @IsRootEntity = @ET_IsRootEntity,
            @DetailPageUrl = @ET_DetailPageUrl,
            @IsMetaData = @ET_IsMetaData,
            @IsDeletable = @ET_IsDeletable,
            @Guid = @EntityTypeGuidToApply OUTPUT;

        FETCH NEXT FROM EntityTypes_Cursor
        INTO
            @Guid,
            @ET_RowStatus,
            @Name,
            @ET_IsReadOnlyOffline,
            @ET_IsRequiredSystemData,
            @ET_HasDocuments,
            @ET_SourceLanguageLabelID,
            @ET_DoNotTrackChanges,
            @ET_SourceIconID,
            @ET_IsRootEntity,
            @ET_DetailPageUrl,
            @ET_IsMetaData,
            @ET_IsDeletable;
    END;

    CLOSE EntityTypes_Cursor;
    DEALLOCATE EntityTypes_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityTypes',
        @StepStatus = N'Succeeded',
        @Message = N'Entity types applied.',
        @DetailsJson = N'{}';


    /* =========================================================
       4. SCore.EntityHobts
       Required reference metadata for EntityQueries and EntityProperties.
       Applies staged HoBTs after EntityTypes and before dependent metadata.
       ========================================================= */
    DECLARE
        @EH_RowStatus TINYINT,
        @EH_SchemaName NVARCHAR(250),
        @EH_ObjectName NVARCHAR(250),
        @EH_SourceEntityTypeID BIGINT,
        @EH_ObjectType NVARCHAR(1),
        @EH_IsMainHoBT BIT,
        @EH_IsReadOnlyOffline BIT,
        @EH_EntityTypeGuid UNIQUEIDENTIFIER;

    DECLARE EntityHobts_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectType'), N'T'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMainHoBT')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityHobts'
        ORDER BY sr.SourceRowId;

    OPEN EntityHobts_Cursor;

    FETCH NEXT FROM EntityHobts_Cursor
    INTO
        @Guid,
        @EH_RowStatus,
        @EH_SchemaName,
        @EH_ObjectName,
        @EH_SourceEntityTypeID,
        @EH_ObjectType,
        @EH_IsMainHoBT,
        @EH_IsReadOnlyOffline;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EH_EntityTypeGuid = NULL;

        SELECT
            @EH_EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @EH_SourceEntityTypeID;

        IF @EH_EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingHoBTEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityHobts apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EH_SourceEntityTypeID), N'<NULL>'), N' for HoBT ', COALESCE(@EH_SchemaName + N'.' + @EH_ObjectName, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityHobts.');
            THROW 52021, @MissingHoBTEntityTypeMessage, 1;
        END;

        DECLARE @EntityHoBTGuidToApply UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityHoBTUpsert
            @SchemaName = @EH_SchemaName,
            @ObjectName = @EH_ObjectName,
            @ObjectType = @EH_ObjectType,
            @IsMainHoBT = @EH_IsMainHoBT,
            @IsReadOnlyOffline = @EH_IsReadOnlyOffline,
            @EntityTypeGuid = @EH_EntityTypeGuid,
            @Guid = @EntityHoBTGuidToApply OUTPUT;

        FETCH NEXT FROM EntityHobts_Cursor
        INTO
            @Guid,
            @EH_RowStatus,
            @EH_SchemaName,
            @EH_ObjectName,
            @EH_SourceEntityTypeID,
            @EH_ObjectType,
            @EH_IsMainHoBT,
            @EH_IsReadOnlyOffline;
    END;

    CLOSE EntityHobts_Cursor;
    DEALLOCATE EntityHobts_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityHobts',
        @StepStatus = N'Succeeded',
        @Message = N'Entity HoBTs applied.',
        @DetailsJson = N'{}';

    /* =========================================================
   10. SUserInterface.DropDownListDefinitions
   ========================================================= */

DECLARE
    @DDL_Code NVARCHAR(20),
    @DDL_NameColumn NVARCHAR(254),
    @DDL_ValueColumn NVARCHAR(254),
    @DDL_SqlQuery NVARCHAR(MAX),
    @DDL_DefaultSortColumnName NVARCHAR(254),
    @DDL_IsDefaultColumn BIT,
    @DDL_IsDetailWindowed BIT,
    @DDL_DetailPageURI NVARCHAR(250),
    @DDL_SourceEntityTypeID BIGINT,
    @DDL_InformationPageURI NVARCHAR(250),
    @DDL_GroupColumn NVARCHAR(254),
    @DDL_ColourHexColumn NVARCHAR(7),
    @DDL_ExternalSearchPageUrl NVARCHAR(250),
    @DDL_EntityTypeGuid UNIQUEIDENTIFIER;

DECLARE DropDownListDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.NameColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ValueColumn'),
        ddlJsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultColumn')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.InformationPageUrl'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.GroupColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ColourHexColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ExternalSearchPageUrl')
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery'
    ) AS ddlJsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'DropDownListDefinitions'
    ORDER BY sr.SourceRowId;

OPEN DropDownListDefinitions_Cursor;

FETCH NEXT FROM DropDownListDefinitions_Cursor
INTO
    @Guid,
    @DDL_Code,
    @DDL_NameColumn,
    @DDL_ValueColumn,
    @DDL_SqlQuery,
    @DDL_DefaultSortColumnName,
    @DDL_IsDefaultColumn,
    @DDL_IsDetailWindowed,
    @DDL_DetailPageURI,
    @DDL_SourceEntityTypeID,
    @DDL_InformationPageURI,
    @DDL_GroupColumn,
    @DDL_ColourHexColumn,
    @DDL_ExternalSearchPageUrl;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DDL_EntityTypeGuid = NULL;
    IF @DDL_SourceEntityTypeID IS NULL OR @DDL_SourceEntityTypeID <= 0
    BEGIN
        SET @DDL_EntityTypeGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @DDL_EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @DDL_SourceEntityTypeID;
    END;

    IF @DDL_EntityTypeGuid IS NULL
    BEGIN
        DECLARE @MissingDDLTargetEntityTypeMessage NVARCHAR(4000) = CONCAT(N'DropDownListDefinitions apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @DDL_SourceEntityTypeID), N'<NULL>'), N' for drop-down list ', COALESCE(@DDL_Code, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SUserInterface.DropDownListDefinitions.');
        THROW 52028, @MissingDDLTargetEntityTypeMessage, 1;
    END;

    DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.DropDownListDefinitionUpsert
        @Code = @DDL_Code,
        @NameColumn = @DDL_NameColumn,
        @ValueColumn = @DDL_ValueColumn,
        @SqlQuery = @DDL_SqlQuery,
        @DefaultSortColumnName = @DDL_DefaultSortColumnName,
        @IsDefaultColumn = @DDL_IsDefaultColumn,
        @IsDetailWindowed = @DDL_IsDetailWindowed,
        @DetailPageURI = @DDL_DetailPageURI,
        @EntityTypeGuid = @DDL_EntityTypeGuid,
        @InformationPageURI = @DDL_InformationPageURI,
        @GroupColumn = @DDL_GroupColumn,
        @Guid = @DropDownListDefinitionGuid OUTPUT,
        @ColourHexColumn = @DDL_ColourHexColumn,
        @ExternalSearchPageUrl = @DDL_ExternalSearchPageUrl;

    FETCH NEXT FROM DropDownListDefinitions_Cursor
    INTO
        @Guid,
        @DDL_Code,
        @DDL_NameColumn,
        @DDL_ValueColumn,
        @DDL_SqlQuery,
        @DDL_DefaultSortColumnName,
        @DDL_IsDefaultColumn,
        @DDL_IsDetailWindowed,
        @DDL_DetailPageURI,
        @DDL_SourceEntityTypeID,
        @DDL_InformationPageURI,
        @DDL_GroupColumn,
        @DDL_ColourHexColumn,
        @DDL_ExternalSearchPageUrl;
END;

CLOSE DropDownListDefinitions_Cursor;
DEALLOCATE DropDownListDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyDropDownListDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Drop-down list definitions applied.',
    @DetailsJson = N'{}';


/* =========================================================
       8. SCore.EntityPropertyGroups
       Required reference metadata for EntityProperties.
       ========================================================= */
    DECLARE
        @EPG_RowStatus TINYINT,
        @EPG_Name NVARCHAR(250),
        @EPG_IsHidden BIT,
        @EPG_SortOrder INT,
        @EPG_SourceLanguageLabelID BIGINT,
        @EPG_SourceEntityTypeID BIGINT,
        @EPG_SourcePropertyGroupLayoutID BIGINT,
        @EPG_ShowOnMobile BIT,
        @EPG_IsCollapsable BIT,
        @EPG_IsDefaultCollapsed BIT,
        @EPG_IsDefaultCollapsed_Mobile BIT,
        @EPG_LanguageLabelGuid UNIQUEIDENTIFIER,
        @EPG_EntityTypeGuid UNIQUEIDENTIFIER,
        @EPG_PropertyGroupLayoutGuid UNIQUEIDENTIFIER;

    DECLARE EntityPropertyGroups_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
            TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.PropertyGroupLayoutID'), JSON_VALUE(sr.SourcePayloadJson, N'$.PropertyGroupLayoutId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCollapsable')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed_Mobile'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityPropertyGroups'
        ORDER BY sr.SourceRowId;

    OPEN EntityPropertyGroups_Cursor;

    FETCH NEXT FROM EntityPropertyGroups_Cursor
    INTO
        @Guid,
        @EPG_RowStatus,
        @EPG_Name,
        @EPG_IsHidden,
        @EPG_SortOrder,
        @EPG_SourceLanguageLabelID,
        @EPG_SourceEntityTypeID,
        @EPG_SourcePropertyGroupLayoutID,
        @EPG_ShowOnMobile,
        @EPG_IsCollapsable,
        @EPG_IsDefaultCollapsed,
        @EPG_IsDefaultCollapsed_Mobile;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EPG_LanguageLabelGuid = NULL;
        SET @EPG_EntityTypeGuid = NULL;
        SET @EPG_PropertyGroupLayoutGuid = NULL;

        IF @EPG_SourceLanguageLabelID IS NULL OR @EPG_SourceLanguageLabelID <= 0
        BEGIN
            SET @EPG_LanguageLabelGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_LanguageLabelGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SCore'
              AND lookup.TableName = N'LanguageLabels'
              AND lookup.SourceRowId = @EPG_SourceLanguageLabelID;
        END;

        IF @EPG_SourceEntityTypeID IS NULL OR @EPG_SourceEntityTypeID <= 0
        BEGIN
            SET @EPG_EntityTypeGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_EntityTypeGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SCore'
              AND lookup.TableName = N'EntityTypes'
              AND lookup.SourceRowId = @EPG_SourceEntityTypeID;
        END;

        IF @EPG_SourcePropertyGroupLayoutID IS NULL OR @EPG_SourcePropertyGroupLayoutID <= 0
        BEGIN
            SET @EPG_PropertyGroupLayoutGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_PropertyGroupLayoutGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SUserInterface'
              AND lookup.TableName = N'PropertyGroupLayouts'
              AND lookup.SourceRowId = @EPG_SourcePropertyGroupLayoutID;
        END;

        IF @EPG_LanguageLabelGuid IS NULL
        BEGIN
            DECLARE @MissingEPGLanguageLabelMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve LanguageLabel source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourceLanguageLabelID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.LanguageLabels is staged/applied before SCore.EntityPropertyGroups.');
            THROW 52025, @MissingEPGLanguageLabelMessage, 1;
        END;

        IF @EPG_EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingEPGEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourceEntityTypeID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityPropertyGroups.');
            THROW 52026, @MissingEPGEntityTypeMessage, 1;
        END;

        IF @EPG_PropertyGroupLayoutGuid IS NULL
        BEGIN
            DECLARE @MissingEPGLayoutMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve PropertyGroupLayout source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourcePropertyGroupLayoutID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SUserInterface.PropertyGroupLayouts is included as reference metadata if this is not the zero/default layout.');
            THROW 52027, @MissingEPGLayoutMessage, 1;
        END;

        DECLARE @EntityPropertyGroupGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityPropertyGroupUpsert
            @Name = @EPG_Name,
            @RowStatus = @EPG_RowStatus,
            @IsHidden = @EPG_IsHidden,
            @SortOrder = @EPG_SortOrder,
            @LanguageLabelGuid = @EPG_LanguageLabelGuid,
            @EntityTypeGuid = @EPG_EntityTypeGuid,
            @PropertyGroupLayoutGuid = @EPG_PropertyGroupLayoutGuid,
            @ShowOnMobile = @EPG_ShowOnMobile,
            @IsCollapsable = @EPG_IsCollapsable,
            @IsDefaultCollapsed = @EPG_IsDefaultCollapsed,
            @IsDefaultCollapsed_Mobile = @EPG_IsDefaultCollapsed_Mobile,
            @Guid = @EntityPropertyGroupGuid OUTPUT;

        FETCH NEXT FROM EntityPropertyGroups_Cursor
        INTO
            @Guid,
            @EPG_RowStatus,
            @EPG_Name,
            @EPG_IsHidden,
            @EPG_SortOrder,
            @EPG_SourceLanguageLabelID,
            @EPG_SourceEntityTypeID,
            @EPG_SourcePropertyGroupLayoutID,
            @EPG_ShowOnMobile,
            @EPG_IsCollapsable,
            @EPG_IsDefaultCollapsed,
            @EPG_IsDefaultCollapsed_Mobile;
    END;

    CLOSE EntityPropertyGroups_Cursor;
    DEALLOCATE EntityPropertyGroups_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityPropertyGroups',
        @StepStatus = N'Succeeded',
        @Message = N'Entity property groups applied.',
        @DetailsJson = N'{}';

/* =========================================================
       5. SCore.EntityQueries
       ========================================================= */
    DECLARE
        @Statement NVARCHAR(MAX),
        @EntityTypeGuid UNIQUEIDENTIFIER,
        @EntityHoBTGuid UNIQUEIDENTIFIER,
        @IsDefaultCreate BIT,
        @IsDefaultRead BIT,
        @IsDefaultUpdate BIT,
        @IsDefaultDelete BIT,
        @IsScalarExecute BIT,
        @IsDefaultValidation BIT,
        @IsDefaultDataPills BIT,
        @IsMergeDocumentQuery BIT,
        @IsProgressData BIT,
        @SchemaName NVARCHAR(255),
        @ObjectName NVARCHAR(255),
        @IsManualStatement BIT,
        @RowStatus TINYINT,
        @SourceEntityTypeId BIGINT,
        @SourceEntityHoBTId BIGINT;

    IF OBJECT_ID(N'tempdb..#EntityQueriesToApply') IS NOT NULL
        DROP TABLE #EntityQueriesToApply;

    CREATE TABLE #EntityQueriesToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        RowStatus TINYINT NULL,
        Name NVARCHAR(500) NULL,
        Statement NVARCHAR(MAX) NULL,
        SourceEntityTypeId BIGINT NULL,
        SourceEntityHoBTId BIGINT NULL,
        IsDefaultCreate BIT NULL,
        IsDefaultRead BIT NULL,
        IsDefaultUpdate BIT NULL,
        IsDefaultDelete BIT NULL,
        IsScalarExecute BIT NULL,
        IsDefaultValidation BIT NULL,
        IsDefaultDataPills BIT NULL,
        IsMergeDocumentQuery BIT NULL,
        IsProgressData BIT NULL,
        SchemaName NVARCHAR(255) NULL,
        ObjectName NVARCHAR(255) NULL,
        IsManualStatement BIT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #EntityQueriesToApply
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        jsonPayload.Statement,
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTId'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtId'))),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCreate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultRead')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultUpdate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDelete')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsScalarExecute')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultValidation')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDataPills')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMergeDocumentQuery')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsProgressData')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsManualStatement')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        Statement NVARCHAR(MAX) N'$.Statement'
    ) AS jsonPayload
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueries';

    DECLARE EntityQueries_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            RowStatus,
            Name,
            Statement,
            SourceEntityTypeId,
            SourceEntityHoBTId,
            IsDefaultCreate,
            IsDefaultRead,
            IsDefaultUpdate,
            IsDefaultDelete,
            IsScalarExecute,
            IsDefaultValidation,
            IsDefaultDataPills,
            IsMergeDocumentQuery,
            IsProgressData,
            SchemaName,
            ObjectName,
            IsManualStatement
        FROM #EntityQueriesToApply
        ORDER BY SourceRowId;

    OPEN EntityQueries_Cursor;

    FETCH NEXT FROM EntityQueries_Cursor
    INTO
        @Guid,
        @RowStatus,
        @Name,
        @Statement,
        @SourceEntityTypeId,
        @SourceEntityHoBTId,
        @IsDefaultCreate,
        @IsDefaultRead,
        @IsDefaultUpdate,
        @IsDefaultDelete,
        @IsScalarExecute,
        @IsDefaultValidation,
        @IsDefaultDataPills,
        @IsMergeDocumentQuery,
        @IsProgressData,
        @SchemaName,
        @ObjectName,
        @IsManualStatement;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EntityTypeGuid = NULL;
        SET @EntityHoBTGuid = NULL;

        SELECT
            @EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @SourceEntityTypeId;

        SELECT
            @EntityHoBTGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityHobts'
          AND lookup.SourceRowId = @SourceEntityHoBTId;

        IF @EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityQueries apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @SourceEntityTypeId), N'<NULL>'), N' for query ', COALESCE(@Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityQueries.');
            THROW 52020, @MissingEntityTypeMessage, 1;
        END;

        DECLARE @EntityQueryGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityQueryUpsert
            @Name = @Name,
            @RowStatus = @RowStatus,
            @Statement = @Statement,
            @EntityTypeGuid = @EntityTypeGuid,
            @IsDefaultCreate = @IsDefaultCreate,
            @IsDefaultRead = @IsDefaultRead,
            @IsDefaultUpdate = @IsDefaultUpdate,
            @IsDefaultDelete = @IsDefaultDelete,
            @IsScalarExecute = @IsScalarExecute,
            @IsDefaultValidation = @IsDefaultValidation,
            @EntityHoBTGuid = @EntityHoBTGuid,
            @IsDefaultDataPills = @IsDefaultDataPills,
            @IsMergeDocumentQuery = @IsMergeDocumentQuery,
            @IsProgressData = @IsProgressData,
            @SchemaName = @SchemaName,
            @ObjectName = @ObjectName,
            @IsManualStatement = @IsManualStatement,
            @Guid = @EntityQueryGuid OUTPUT;

        FETCH NEXT FROM EntityQueries_Cursor
        INTO
            @Guid,
            @RowStatus,
            @Name,
            @Statement,
            @SourceEntityTypeId,
            @SourceEntityHoBTId,
            @IsDefaultCreate,
            @IsDefaultRead,
            @IsDefaultUpdate,
            @IsDefaultDelete,
            @IsScalarExecute,
            @IsDefaultValidation,
            @IsDefaultDataPills,
            @IsMergeDocumentQuery,
            @IsProgressData,
            @SchemaName,
            @ObjectName,
            @IsManualStatement;
    END;

    CLOSE EntityQueries_Cursor;
    DEALLOCATE EntityQueries_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityQueries',
        @StepStatus = N'Succeeded',
        @Message = N'Entity queries applied.',
        @DetailsJson = N'{}';

/* =========================================================
   5. SCore.EntityProperties
   ========================================================= */

DECLARE
    @EP_RowStatus TINYINT,
    @EP_Name NVARCHAR(500),
    @EP_SourceLanguageLabelID BIGINT,
    @EP_SourceEntityHoBTID BIGINT,
    @EP_SourceEntityDataTypeID BIGINT,
    @EP_SourceEntityPropertyGroupID BIGINT,
    @EP_SourceDropDownListDefinitionID BIGINT,
    @EP_SourceRowId BIGINT,
    @EP_LanguageLabelGuid UNIQUEIDENTIFIER,
    @EP_EntityHoBTGuid UNIQUEIDENTIFIER,
    @EP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EP_EntityPropertyGroupGuid UNIQUEIDENTIFIER,
    @EP_DropDownListDefinitionGuid UNIQUEIDENTIFIER,
    @EP_IsReadOnly BIT,
    @EP_IsImmutable BIT,
    @EP_IsUppercase BIT,
    @EP_IsHidden BIT,
    @EP_IsCompulsory BIT,
    @EP_MaxLength INT,
    @EP_Precision INT,
    @EP_Scale INT,
    @EP_DoNotTrackChanges BIT,
    @EP_SortOrder SMALLINT,
    @EP_GroupSortOrder SMALLINT,
    @EP_IsObjectLabel BIT,
    @EP_IsParentRelationship BIT,
    @EP_IsIncludedInformation BIT,
    @EP_IsLatitude BIT,
    @EP_IsLongitude BIT,
    @EP_FixDefaultValue NVARCHAR(100),
    @EP_SqlDefaultValueStatement NVARCHAR(MAX),
    @EP_AllowBulkChange BIT,
    @EP_IsVirtual BIT,
    @EP_ShowOnMobile BIT,
    @EP_IsAlwaysVisibleInGroup BIT,
    @EP_IsAlwaysVisibleInGroup_Mobile BIT;

IF OBJECT_ID(N'tempdb..#EntityPropertiesToApply') IS NOT NULL
    DROP TABLE #EntityPropertiesToApply;

CREATE TABLE #EntityPropertiesToApply
(
    Guid UNIQUEIDENTIFIER NOT NULL,
    RowStatus TINYINT NULL,
    Name NVARCHAR(500) NULL,
    SourceLanguageLabelID BIGINT NULL,
    SourceEntityHoBTID BIGINT NULL,
    SourceEntityDataTypeID BIGINT NULL,
    IsReadOnly BIT NULL,
    IsImmutable BIT NULL,
    IsUppercase BIT NULL,
    IsHidden BIT NULL,
    IsCompulsory BIT NULL,
    MaxLength INT NULL,
    PrecisionValue INT NULL,
    ScaleValue INT NULL,
    DoNotTrackChanges BIT NULL,
    SourceEntityPropertyGroupID BIGINT NULL,
    SortOrder SMALLINT NULL,
    GroupSortOrder SMALLINT NULL,
    IsObjectLabel BIT NULL,
    SourceDropDownListDefinitionID BIGINT NULL,
    IsParentRelationship BIT NULL,
    IsIncludedInformation BIT NULL,
    IsLatitude BIT NULL,
    IsLongitude BIT NULL,
    FixDefaultValue NVARCHAR(100) NULL,
    SqlDefaultValueStatement NVARCHAR(MAX) NULL,
    AllowBulkChange BIT NULL,
    IsVirtual BIT NULL,
    ShowOnMobile BIT NULL,
    IsAlwaysVisibleInGroup BIT NULL,
    IsAlwaysVisibleInGroup_Mobile BIT NULL,
    SourceRowId BIGINT NULL
);

INSERT INTO #EntityPropertiesToApply
SELECT
    sr.SourceRowGuid,
    TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
    JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTId'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtId'))),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeId'))),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnly')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsImmutable')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsUppercase')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCompulsory')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MaxLength')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Precision')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Scale')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupId'))),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GroupSortOrder')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsObjectLabel')),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionId'))),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsParentRelationship')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsIncludedInformation')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLatitude')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLongitude')),
    ISNULL
    (
        COALESCE
        (
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixedDefaultValue'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixDefaultValue')
        ),
        N''
    ),
    epjson.SqlDefaultValueStatement,
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsVirtual')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup_Mobile')),
    sr.SourceRowId
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = sr.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
OUTER APPLY OPENJSON(sr.SourcePayloadJson)
WITH
(
    SqlDefaultValueStatement NVARCHAR(MAX) N'$.SqlDefaultValueStatement'
) AS epjson
WHERE sr.RunGuid = @RunGuid
  AND sr.RowStatus NOT IN (0,254)
  AND sr.DifferenceType IN (N'Insert', N'Update')
  AND tr.SchemaName = N'SCore'
  AND tr.TableName = N'EntityProperties';

DECLARE EntityProperties_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        Guid,
        RowStatus,
        Name,
        SourceLanguageLabelID,
        SourceEntityHoBTID,
        SourceEntityDataTypeID,
        IsReadOnly,
        IsImmutable,
        IsUppercase,
        IsHidden,
        IsCompulsory,
        MaxLength,
        PrecisionValue,
        ScaleValue,
        DoNotTrackChanges,
        SourceEntityPropertyGroupID,
        SortOrder,
        GroupSortOrder,
        IsObjectLabel,
        SourceDropDownListDefinitionID,
        IsParentRelationship,
        IsIncludedInformation,
        IsLatitude,
        IsLongitude,
        FixDefaultValue,
        SqlDefaultValueStatement,
        AllowBulkChange,
        IsVirtual,
        ShowOnMobile,
        IsAlwaysVisibleInGroup,
        IsAlwaysVisibleInGroup_Mobile,
        SourceRowId
    FROM #EntityPropertiesToApply
    ORDER BY SourceRowId;

OPEN EntityProperties_Cursor;

FETCH NEXT FROM EntityProperties_Cursor
INTO
    @Guid,
    @EP_RowStatus,
    @EP_Name,
    @EP_SourceLanguageLabelID,
    @EP_SourceEntityHoBTID,
    @EP_SourceEntityDataTypeID,
    @EP_IsReadOnly,
    @EP_IsImmutable,
    @EP_IsUppercase,
    @EP_IsHidden,
    @EP_IsCompulsory,
    @EP_MaxLength,
    @EP_Precision,
    @EP_Scale,
    @EP_DoNotTrackChanges,
    @EP_SourceEntityPropertyGroupID,
    @EP_SortOrder,
    @EP_GroupSortOrder,
    @EP_IsObjectLabel,
    @EP_SourceDropDownListDefinitionID,
    @EP_IsParentRelationship,
    @EP_IsIncludedInformation,
    @EP_IsLatitude,
    @EP_IsLongitude,
    @EP_FixDefaultValue,
    @EP_SqlDefaultValueStatement,
    @EP_AllowBulkChange,
    @EP_IsVirtual,
    @EP_ShowOnMobile,
    @EP_IsAlwaysVisibleInGroup,
    @EP_IsAlwaysVisibleInGroup_Mobile,
    @EP_SourceRowId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EP_LanguageLabelGuid = NULL;
    SET @EP_EntityHoBTGuid = NULL;
    SET @EP_EntityDataTypeGuid = NULL;
    SET @EP_EntityPropertyGroupGuid = NULL;
    SET @EP_DropDownListDefinitionGuid = NULL;
    SET @EP_FixDefaultValue = ISNULL(@EP_FixDefaultValue, N'');
    SELECT
        @EP_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @EP_SourceLanguageLabelID;

    SELECT
        @EP_EntityHoBTGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityHobts'
      AND lookup.SourceRowId = @EP_SourceEntityHoBTID;

    IF @EP_SourceEntityDataTypeID IS NULL OR @EP_SourceEntityDataTypeID <= 0
    BEGIN
        SET @EP_EntityDataTypeGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_EntityDataTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityDataTypes'
          AND lookup.SourceRowId = @EP_SourceEntityDataTypeID;
    END;

    IF @EP_SourceEntityPropertyGroupID IS NULL OR @EP_SourceEntityPropertyGroupID <= 0
    BEGIN
        SET @EP_EntityPropertyGroupGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_EntityPropertyGroupGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityPropertyGroups'
          AND lookup.SourceRowId = @EP_SourceEntityPropertyGroupID;
    END;

    IF @EP_SourceDropDownListDefinitionID IS NULL OR @EP_SourceDropDownListDefinitionID <= 0
    BEGIN
        SET @EP_DropDownListDefinitionGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_DropDownListDefinitionGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'DropDownListDefinitions'
          AND lookup.SourceRowId = @EP_SourceDropDownListDefinitionID;
    END;

    IF @EP_EntityDataTypeGuid IS NULL
    BEGIN
        DECLARE @MissingEntityDataTypeMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityDataType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityDataTypeID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityDataTypes is staged/applied before SCore.EntityProperties.');
        THROW 52022, @MissingEntityDataTypeMessage, 1;
    END;

    IF @EP_EntityPropertyGroupGuid IS NULL
    BEGIN
        DECLARE @MissingEntityPropertyGroupMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityPropertyGroup source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityPropertyGroupID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityPropertyGroups is staged/applied before SCore.EntityProperties.');
        THROW 52023, @MissingEntityPropertyGroupMessage, 1;
    END;

    IF @EP_DropDownListDefinitionGuid IS NULL
    BEGIN
        DECLARE @MissingDropDownListDefinitionMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve DropDownListDefinition source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceDropDownListDefinitionID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SUserInterface.DropDownListDefinitions is applied before SCore.EntityProperties.');
        THROW 52024, @MissingDropDownListDefinitionMessage, 1;
    END;

    DECLARE @ExistingEntityPropertyGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @ExistingEntityPropertyGuid = ep.Guid
    FROM SCore.EntityProperties AS ep
    INNER JOIN SCore.EntityHobts AS eh
        ON eh.ID = ep.EntityHoBTID
       AND eh.RowStatus NOT IN (0,254)
    WHERE eh.Guid = @EP_EntityHoBTGuid
      AND ep.Name = @EP_Name
      AND ep.RowStatus NOT IN (0,254)
      AND ep.Guid <> @Guid
    ORDER BY ep.ID;

    DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER = ISNULL(@ExistingEntityPropertyGuid, @Guid);

    IF @ExistingEntityPropertyGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingEntityPropertyGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityProperties'
          AND lookup.SourceRowId = @EP_SourceRowId;
    END;

    EXEC SCore.EntityPropertyUpsert
        @Name = @EP_Name,
        @RowStatus = @EP_RowStatus,
        @LanguageLabelGuid = @EP_LanguageLabelGuid,
        @EntityHobtGuid = @EP_EntityHoBTGuid,
        @EntityDataTypeGuid = @EP_EntityDataTypeGuid,
        @IsReadOnly = @EP_IsReadOnly,
        @IsImmutable = @EP_IsImmutable,
        @IsUppercase = @EP_IsUppercase,
        @IsHidden = @EP_IsHidden,
        @IsCompulsory = @EP_IsCompulsory,
        @MaxLength = @EP_MaxLength,
        @Precision = @EP_Precision,
        @Scale = @EP_Scale,
        @DoNotTrackChanges = @EP_DoNotTrackChanges,
        @EntityPropertyGroupGuid = @EP_EntityPropertyGroupGuid,
        @SortOrder = @EP_SortOrder,
        @GroupSortOrder = @EP_GroupSortOrder,
        @IsObjectLabel = @EP_IsObjectLabel,
        @DropDownListDefinitionGuid = @EP_DropDownListDefinitionGuid,
        @IsParentRelationship = @EP_IsParentRelationship,
        @IsIncludedInformation = @EP_IsIncludedInformation,
        @IsLatitude = @EP_IsLatitude,
        @IsLongitude = @EP_IsLongitude,
        @FixDefaultValue = @EP_FixDefaultValue,
        @SqlDefaultValueStatement = @EP_SqlDefaultValueStatement,
        @AllowBulkChange = @EP_AllowBulkChange,
        @IsVirtual = @EP_IsVirtual,
        @ShowOnMobile = @EP_ShowOnMobile,
        @IsAlwaysVisibleInGroup = @EP_IsAlwaysVisibleInGroup,
        @IsAlwaysVisibleInGroup_Mobile = @EP_IsAlwaysVisibleInGroup_Mobile,
        @Guid = @EntityPropertyGuid OUTPUT;

    FETCH NEXT FROM EntityProperties_Cursor
    INTO
        @Guid,
        @EP_RowStatus,
        @EP_Name,
        @EP_SourceLanguageLabelID,
        @EP_SourceEntityHoBTID,
        @EP_SourceEntityDataTypeID,
        @EP_IsReadOnly,
        @EP_IsImmutable,
        @EP_IsUppercase,
        @EP_IsHidden,
        @EP_IsCompulsory,
        @EP_MaxLength,
        @EP_Precision,
        @EP_Scale,
        @EP_DoNotTrackChanges,
        @EP_SourceEntityPropertyGroupID,
        @EP_SortOrder,
        @EP_GroupSortOrder,
        @EP_IsObjectLabel,
        @EP_SourceDropDownListDefinitionID,
        @EP_IsParentRelationship,
        @EP_IsIncludedInformation,
        @EP_IsLatitude,
        @EP_IsLongitude,
        @EP_FixDefaultValue,
        @EP_SqlDefaultValueStatement,
        @EP_AllowBulkChange,
        @EP_IsVirtual,
        @EP_ShowOnMobile,
        @EP_IsAlwaysVisibleInGroup,
        @EP_IsAlwaysVisibleInGroup_Mobile,
        @EP_SourceRowId;
END;

CLOSE EntityProperties_Cursor;
DEALLOCATE EntityProperties_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityProperties',
    @StepStatus = N'Succeeded',
    @Message = N'Entity properties applied.',
    @DetailsJson = N'{}';

/* =========================================================
   6. SCore.EntityQueryParameters
   ========================================================= */

DECLARE
    @EQP_RowStatus TINYINT,
    @EQP_Name NVARCHAR(500),
    @EQP_SourceEntityQueryID BIGINT,
    @EQP_SourceEntityDataTypeID BIGINT,
    @EQP_SourceMappedEntityPropertyID BIGINT,
    @EQP_EntityQueryGuid UNIQUEIDENTIFIER,
    @EQP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EQP_MappedEntityPropertyGuid UNIQUEIDENTIFIER,
    @EQP_DefaultValue NVARCHAR(200),
    @EQP_IsInput BIT,
    @EQP_IsOutput BIT,
    @EQP_IsReturnColumn BIT;

DECLARE EntityQueryParameters_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyID'), JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultValue'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsInput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsOutput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReturnColumn'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueryParameters'
    ORDER BY sr.SourceRowId;

OPEN EntityQueryParameters_Cursor;

FETCH NEXT FROM EntityQueryParameters_Cursor
INTO
    @Guid,
    @EQP_RowStatus,
    @EQP_Name,
    @EQP_SourceEntityQueryID,
    @EQP_SourceEntityDataTypeID,
    @EQP_SourceMappedEntityPropertyID,
    @EQP_DefaultValue,
    @EQP_IsInput,
    @EQP_IsOutput,
    @EQP_IsReturnColumn;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EQP_EntityQueryGuid = NULL;
    SET @EQP_EntityDataTypeGuid = NULL;
    SET @EQP_MappedEntityPropertyGuid = NULL;
    SELECT
        @EQP_EntityQueryGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityQueries'
      AND lookup.SourceRowId = @EQP_SourceEntityQueryID;

    SELECT
        @EQP_EntityDataTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityDataTypes'
      AND lookup.SourceRowId = @EQP_SourceEntityDataTypeID;

    SELECT
        @EQP_MappedEntityPropertyGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityProperties'
      AND lookup.SourceRowId = @EQP_SourceMappedEntityPropertyID;

    DECLARE @EntityQueryParameterGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SCore.EntityQueryParameterUpsert
        @Name = @EQP_Name,
        @RowStatus = @EQP_RowStatus,
        @EntityQueryGuid = @EQP_EntityQueryGuid,
        @EntityDataTypeGuid = @EQP_EntityDataTypeGuid,
        @MappedEntityPropertyGuid = @EQP_MappedEntityPropertyGuid,
        @DefaultValue = @EQP_DefaultValue,
        @IsInput = @EQP_IsInput,
        @IsOutput = @EQP_IsOutput,
        @IsReturnColumn = @EQP_IsReturnColumn,
        @Guid = @EntityQueryParameterGuid OUTPUT;

    FETCH NEXT FROM EntityQueryParameters_Cursor
    INTO
        @Guid,
        @EQP_RowStatus,
        @EQP_Name,
        @EQP_SourceEntityQueryID,
        @EQP_SourceEntityDataTypeID,
        @EQP_SourceMappedEntityPropertyID,
        @EQP_DefaultValue,
        @EQP_IsInput,
        @EQP_IsOutput,
        @EQP_IsReturnColumn;
END;

CLOSE EntityQueryParameters_Cursor;
DEALLOCATE EntityQueryParameters_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityQueryParameters',
    @StepStatus = N'Succeeded',
    @Message = N'Entity query parameters applied.',
    @DetailsJson = N'{}';


/* =========================================================
   7. SUserInterface.GridDefinitions
   ========================================================= */

DECLARE
    @GD_RowStatus TINYINT,
    @GD_Code NVARCHAR(30),
    @GD_TabName NVARCHAR(250),
    @GD_ShowAsTiles BIT,
    @GD_PageUri NVARCHAR(250),
    @GD_SourceLanguageLabelID BIGINT,
    @GD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TabName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowAsTiles')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.PageUri'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId')))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridDefinitions_Cursor;

FETCH NEXT FROM GridDefinitions_Cursor
INTO
    @Guid,
    @GD_RowStatus,
    @GD_Code,
    @GD_TabName,
    @GD_ShowAsTiles,
    @GD_PageUri,
    @GD_SourceLanguageLabelID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GD_LanguageLabelGuid = NULL;
    SELECT
        @GD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GD_SourceLanguageLabelID;

    DECLARE @GridDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridDefinitionUpsert
        @Code = @GD_Code,
        @RowStatus = @GD_RowStatus,
        @TabName = @GD_TabName,
        @ShowAsTiles = @GD_ShowAsTiles,
        @PageUri = @GD_PageUri,
        @LanguageLabelGuid = @GD_LanguageLabelGuid,
        @Guid = @GridDefinitionGuid OUTPUT;

    FETCH NEXT FROM GridDefinitions_Cursor
    INTO
        @Guid,
        @GD_RowStatus,
        @GD_Code,
        @GD_TabName,
        @GD_ShowAsTiles,
        @GD_PageUri,
        @GD_SourceLanguageLabelID;
END;

CLOSE GridDefinitions_Cursor;
DEALLOCATE GridDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   8. SUserInterface.GridViewDefinitions
   ========================================================= */

DECLARE
    @GVD_RowStatus TINYINT,
    @GVD_Code NVARCHAR(20),
    @GVD_SourceGridDefinitionID BIGINT,
    @GVD_DetailPageUri NVARCHAR(250),
    @GVD_SqlQuery NVARCHAR(MAX),
    @GVD_DefaultSortColumnName NVARCHAR(250),
    @GVD_SecurableCode NVARCHAR(20),
    @GVD_DisplayOrder INT,
    @GVD_DisplayGroupName NVARCHAR(50),
    @GVD_MetricSqlQuery NVARCHAR(MAX),
    @GVD_ShowMetric BIT,
    @GVD_IsDetailWindowed BIT,
    @GVD_SourceEntityTypeID BIGINT,
    @GVD_SourceMetricTypeID BIGINT,
    @GVD_MetricMin INT,
    @GVD_MetricMax INT,
    @GVD_MetricMinorUnit INT,
    @GVD_MetricMajorUnit INT,
    @GVD_MetricStartAngle INT,
    @GVD_MetricEndAngle INT,
    @GVD_MetricReversed BIT,
    @GVD_MetricRange1Min DECIMAL(18,0),
    @GVD_MetricRange1Max DECIMAL(18,0),
    @GVD_MetricRange1ColourHex NVARCHAR(10),
    @GVD_MetricRange2Min DECIMAL(18,0),
    @GVD_MetricRange2Max DECIMAL(18,0),
    @GVD_MetricRange2ColourHex NVARCHAR(10),
    @GVD_IsDefaultSortDescending BIT,
    @GVD_ShowOnMobile BIT,
    @GVD_AllowNew BIT,
    @GVD_AllowExcelExport BIT,
    @GVD_AllowPdfExport BIT,
    @GVD_AllowCsvExport BIT,
    @GVD_SourceLanguageLabelID BIGINT,
    @GVD_SourceDrawerIconID BIGINT,
    @GVD_SourceGridViewTypeID BIGINT,
    @GVD_AllowBulkChange BIT,
    @GVD_TreeListFirstOrderBy NVARCHAR(100),
    @GVD_TreeListSecondOrderBy NVARCHAR(100),
    @GVD_TreeListThirdOrderBy NVARCHAR(100),
    @GVD_TreeListOrderBy NVARCHAR(100),
    @GVD_TreeListGroupBy NVARCHAR(100),
    @GVD_ShowOnDashboard BIT,
    @GVD_FilteredListCreatedOnColumn NVARCHAR(100),
    @GVD_FilteredListRedStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListOrangeStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGreenStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGroupBy NVARCHAR(100),
    @GVD_IsHidden BIT,
    @GVD_GridDefinitionGuid UNIQUEIDENTIFIER,
    @GVD_EntityTypeGuid UNIQUEIDENTIFIER,
    @GVD_MetricTypeGuid UNIQUEIDENTIFIER,
    @GVD_LanguageLabelGuid UNIQUEIDENTIFIER,
    @GVD_DrawerIconGuid UNIQUEIDENTIFIER,
    @GVD_GridViewTypeGuid UNIQUEIDENTIFIER;

DECLARE GridViewDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUri'),
        jsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SecurableCode'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayOrder')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayGroupName'),
        jsonValues.MetricSqlQuery,
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowMetric')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeId'))),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMin')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMax')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMinorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMajorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricStartAngle')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricEndAngle')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricReversed')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1ColourHex'),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2ColourHex'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultSortDescending')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowNew')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowExcelExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowPdfExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowCsvExport')),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconID'), JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeId'))),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListFirstOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListSecondOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListThirdOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnDashboard')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListCreatedOnColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListRedStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListOrangeStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGreenStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden'))
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery',
        MetricSqlQuery NVARCHAR(MAX) N'$.MetricSqlQuery'
    ) AS jsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewDefinitions_Cursor;

FETCH NEXT FROM GridViewDefinitions_Cursor
INTO
    @Guid,
    @GVD_RowStatus,
    @GVD_Code,
    @GVD_SourceGridDefinitionID,
    @GVD_DetailPageUri,
    @GVD_SqlQuery,
    @GVD_DefaultSortColumnName,
    @GVD_SecurableCode,
    @GVD_DisplayOrder,
    @GVD_DisplayGroupName,
    @GVD_MetricSqlQuery,
    @GVD_ShowMetric,
    @GVD_IsDetailWindowed,
    @GVD_SourceEntityTypeID,
    @GVD_SourceMetricTypeID,
    @GVD_MetricMin,
    @GVD_MetricMax,
    @GVD_MetricMinorUnit,
    @GVD_MetricMajorUnit,
    @GVD_MetricStartAngle,
    @GVD_MetricEndAngle,
    @GVD_MetricReversed,
    @GVD_MetricRange1Min,
    @GVD_MetricRange1Max,
    @GVD_MetricRange1ColourHex,
    @GVD_MetricRange2Min,
    @GVD_MetricRange2Max,
    @GVD_MetricRange2ColourHex,
    @GVD_IsDefaultSortDescending,
    @GVD_ShowOnMobile,
    @GVD_AllowNew,
    @GVD_AllowExcelExport,
    @GVD_AllowPdfExport,
    @GVD_AllowCsvExport,
    @GVD_SourceLanguageLabelID,
    @GVD_SourceDrawerIconID,
    @GVD_SourceGridViewTypeID,
    @GVD_AllowBulkChange,
    @GVD_TreeListFirstOrderBy,
    @GVD_TreeListSecondOrderBy,
    @GVD_TreeListThirdOrderBy,
    @GVD_TreeListOrderBy,
    @GVD_TreeListGroupBy,
    @GVD_ShowOnDashboard,
    @GVD_FilteredListCreatedOnColumn,
    @GVD_FilteredListRedStatusIndicatorTxt,
    @GVD_FilteredListOrangeStatusIndicatorTxt,
    @GVD_FilteredListGreenStatusIndicatorTxt,
    @GVD_FilteredListGroupBy,
    @GVD_IsHidden;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVD_GridDefinitionGuid = NULL;
    SET @GVD_EntityTypeGuid = NULL;
    SET @GVD_MetricTypeGuid = NULL;
    SET @GVD_LanguageLabelGuid = NULL;
    SET @GVD_DrawerIconGuid = NULL;
    SET @GVD_GridViewTypeGuid = NULL;
    SELECT
        @GVD_GridDefinitionGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridDefinitions'
      AND lookup.SourceRowId = @GVD_SourceGridDefinitionID;

    SELECT
        @GVD_EntityTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityTypes'
      AND lookup.SourceRowId = @GVD_SourceEntityTypeID;

    SELECT
        @GVD_MetricTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'MetricTypes'
      AND lookup.SourceRowId = @GVD_SourceMetricTypeID;

    SELECT
        @GVD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GVD_SourceLanguageLabelID;

    SELECT
        @GVD_DrawerIconGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'Icons'
      AND lookup.SourceRowId = @GVD_SourceDrawerIconID;

    SELECT
        @GVD_GridViewTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridViewTypes'
      AND lookup.SourceRowId = @GVD_SourceGridViewTypeID;

    DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridViewDefinitionUpsert
        @Code = @GVD_Code,
        @RowStatus = @GVD_RowStatus,
        @GridDefinitionGuid = @GVD_GridDefinitionGuid,
        @DetailPageUri = @GVD_DetailPageUri,
        @SqlQuery = @GVD_SqlQuery,
        @DefaultSortColumnName = @GVD_DefaultSortColumnName,
        @SecurableCode = @GVD_SecurableCode,
        @DisplayOrder = @GVD_DisplayOrder,
        @DisplayGroupName = @GVD_DisplayGroupName,
        @MetricSqlQuery = @GVD_MetricSqlQuery,
        @ShowMetric = @GVD_ShowMetric,
        @IsDetailWindowed = @GVD_IsDetailWindowed,
        @EntityTypeGuid = @GVD_EntityTypeGuid,
        @MetricTypeGuid = @GVD_MetricTypeGuid,
        @MetricMin = @GVD_MetricMin,
        @MetricMax = @GVD_MetricMax,
        @MetricMinorUnit = @GVD_MetricMinorUnit,
        @MetricMajorUnit = @GVD_MetricMajorUnit,
        @MetricStartAngle = @GVD_MetricStartAngle,
        @MetricEndAngle = @GVD_MetricEndAngle,
        @MetricReversed = @GVD_MetricReversed,
        @MetricRange1Min = @GVD_MetricRange1Min,
        @MetricRange1Max = @GVD_MetricRange1Max,
        @MetricRange1ColourHex = @GVD_MetricRange1ColourHex,
        @MetricRange2Min = @GVD_MetricRange2Min,
        @MetricRange2Max = @GVD_MetricRange2Max,
        @MetricRange2ColourHex = @GVD_MetricRange2ColourHex,
        @IsDefaultSortDescending = @GVD_IsDefaultSortDescending,
        @AllowNew = @GVD_AllowNew,
        @AllowExcelExport = @GVD_AllowExcelExport,
        @AllowPdfExport = @GVD_AllowPdfExport,
        @AllowCsvExport = @GVD_AllowCsvExport,
        @LanguageLabelGuid = @GVD_LanguageLabelGuid,
        @DrawerIconGuid = @GVD_DrawerIconGuid,
        @GridViewTypeGuid = @GVD_GridViewTypeGuid,
        @AllowBulkChange = @GVD_AllowBulkChange,
        @Guid = @GridViewDefinitionGuid OUTPUT,
        @ShowOnMobile = @GVD_ShowOnMobile,
        @TreeListFirstOrderBy = @GVD_TreeListFirstOrderBy,
        @TreeListSecondOrderBy = @GVD_TreeListSecondOrderBy,
        @TreeListThirdOrderBy = @GVD_TreeListThirdOrderBy,
        @TreeListOrderBy = @GVD_TreeListOrderBy,
        @TreeListGroupBy = @GVD_TreeListGroupBy,
        @ShowOnDashboard = @GVD_ShowOnDashboard,
        @FilteredListCreatedOnColumn = @GVD_FilteredListCreatedOnColumn,
        @FilteredListRedStatusIndicatorTxt = @GVD_FilteredListRedStatusIndicatorTxt,
        @FilteredListOrangeStatusIndicatorTxt = @GVD_FilteredListOrangeStatusIndicatorTxt,
        @FilteredListGreenStatusIndicatorTxt = @GVD_FilteredListGreenStatusIndicatorTxt,
        @FilteredListGroupBy = @GVD_FilteredListGroupBy,
        @IsHidden = @GVD_IsHidden;

    FETCH NEXT FROM GridViewDefinitions_Cursor
    INTO
        @Guid,
        @GVD_RowStatus,
        @GVD_Code,
        @GVD_SourceGridDefinitionID,
        @GVD_DetailPageUri,
        @GVD_SqlQuery,
        @GVD_DefaultSortColumnName,
        @GVD_SecurableCode,
        @GVD_DisplayOrder,
        @GVD_DisplayGroupName,
        @GVD_MetricSqlQuery,
        @GVD_ShowMetric,
        @GVD_IsDetailWindowed,
        @GVD_SourceEntityTypeID,
        @GVD_SourceMetricTypeID,
        @GVD_MetricMin,
        @GVD_MetricMax,
        @GVD_MetricMinorUnit,
        @GVD_MetricMajorUnit,
        @GVD_MetricStartAngle,
        @GVD_MetricEndAngle,
        @GVD_MetricReversed,
        @GVD_MetricRange1Min,
        @GVD_MetricRange1Max,
        @GVD_MetricRange1ColourHex,
        @GVD_MetricRange2Min,
        @GVD_MetricRange2Max,
        @GVD_MetricRange2ColourHex,
        @GVD_IsDefaultSortDescending,
        @GVD_ShowOnMobile,
        @GVD_AllowNew,
        @GVD_AllowExcelExport,
        @GVD_AllowPdfExport,
        @GVD_AllowCsvExport,
        @GVD_SourceLanguageLabelID,
        @GVD_SourceDrawerIconID,
        @GVD_SourceGridViewTypeID,
        @GVD_AllowBulkChange,
        @GVD_TreeListFirstOrderBy,
        @GVD_TreeListSecondOrderBy,
        @GVD_TreeListThirdOrderBy,
        @GVD_TreeListOrderBy,
        @GVD_TreeListGroupBy,
        @GVD_ShowOnDashboard,
        @GVD_FilteredListCreatedOnColumn,
        @GVD_FilteredListRedStatusIndicatorTxt,
        @GVD_FilteredListOrangeStatusIndicatorTxt,
        @GVD_FilteredListGreenStatusIndicatorTxt,
        @GVD_FilteredListGroupBy,
        @GVD_IsHidden;
END;

CLOSE GridViewDefinitions_Cursor;
DEALLOCATE GridViewDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   9. SUserInterface.GridViewColumnDefinitions
   ========================================================= */

DECLARE
    @GVCD_RowStatus TINYINT,
    @GVCD_Name NVARCHAR(250),
    @GVCD_SourceGridViewDefinitionID BIGINT,
    @GVCD_ColumnOrder INT,
    @GVCD_IsPrimaryKey BIT,
    @GVCD_IsHidden BIT,
    @GVCD_IsFiltered BIT,
    @GVCD_IsCombo BIT,
    @GVCD_DisplayFormat NVARCHAR(50),
    @GVCD_Width NVARCHAR(10),
    @GVCD_SourceLanguageLabelID BIGINT,
    @GVCD_TopHeaderCategory NVARCHAR(50),
    @GVCD_TopHeaderCategoryOrder INT,
    @GVCD_SourceRowId BIGINT,
    @GVCD_GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridViewColumnDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionId'))),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.ColumnOrder')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsPrimaryKey')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsFiltered')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCombo')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayFormat'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Width'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategory'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategoryOrder')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewColumnDefinitions_Cursor;

FETCH NEXT FROM GridViewColumnDefinitions_Cursor
INTO
    @Guid,
    @GVCD_RowStatus,
    @GVCD_Name,
    @GVCD_SourceGridViewDefinitionID,
    @GVCD_ColumnOrder,
    @GVCD_IsPrimaryKey,
    @GVCD_IsHidden,
    @GVCD_IsFiltered,
    @GVCD_IsCombo,
    @GVCD_DisplayFormat,
    @GVCD_Width,
    @GVCD_SourceLanguageLabelID,
    @GVCD_TopHeaderCategory,
    @GVCD_TopHeaderCategoryOrder,
    @GVCD_SourceRowId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVCD_GridViewDefinitionGuid = NULL;
    SET @GVCD_LanguageLabelGuid = NULL;
    SELECT
        @GVCD_GridViewDefinitionGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridViewDefinitions'
      AND lookup.SourceRowId = @GVCD_SourceGridViewDefinitionID;

    SELECT
        @GVCD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GVCD_SourceLanguageLabelID;

    DECLARE @ExistingGridViewColumnDefinitionGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @ExistingGridViewColumnDefinitionGuid = gvcd.Guid
    FROM SUserInterface.GridViewColumnDefinitions AS gvcd
    INNER JOIN SUserInterface.GridViewDefinitions AS gvd
        ON gvd.ID = gvcd.GridViewDefinitionID
       AND gvd.RowStatus NOT IN (0,254)
    WHERE gvd.Guid = @GVCD_GridViewDefinitionGuid
      AND gvcd.RowStatus NOT IN (0,254)
      AND gvcd.Guid <> @Guid
      AND
      (
          (
              ISNULL(@GVCD_IsPrimaryKey, 0) = 1
              AND gvcd.IsPrimaryKey = 1
          )
          OR
          (
              ISNULL(@GVCD_IsPrimaryKey, 0) = 0
              AND gvcd.Name = @GVCD_Name
          )
      )
    ORDER BY
        CASE WHEN ISNULL(@GVCD_IsPrimaryKey, 0) = 1 AND gvcd.IsPrimaryKey = 1 THEN 0 ELSE 1 END,
        gvcd.ID;

    DECLARE @GridViewColumnDefinitionGuid UNIQUEIDENTIFIER = ISNULL(@ExistingGridViewColumnDefinitionGuid, @Guid);

    IF @ExistingGridViewColumnDefinitionGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingGridViewColumnDefinitionGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'GridViewColumnDefinitions'
          AND lookup.SourceRowId = @GVCD_SourceRowId;
    END;

    EXEC SUserInterface.GridViewColumnDefinitionUpsert
        @Name = @GVCD_Name,
        @RowStatus = @GVCD_RowStatus,
        @GridViewDefinitionGuid = @GVCD_GridViewDefinitionGuid,
        @ColumnOrder = @GVCD_ColumnOrder,
        @IsPrimaryKey = @GVCD_IsPrimaryKey,
        @IsHidden = @GVCD_IsHidden,
        @IsFiltered = @GVCD_IsFiltered,
        @IsCombo = @GVCD_IsCombo,
        @DisplayFormat = @GVCD_DisplayFormat,
        @Width = @GVCD_Width,
        @LanguageLabelGuid = @GVCD_LanguageLabelGuid,
        @Guid = @GridViewColumnDefinitionGuid OUTPUT,
        @TopHeaderCategory = @GVCD_TopHeaderCategory,
        @TopHeaderCategoryOrder = @GVCD_TopHeaderCategoryOrder;

    FETCH NEXT FROM GridViewColumnDefinitions_Cursor
    INTO
        @Guid,
        @GVCD_RowStatus,
        @GVCD_Name,
        @GVCD_SourceGridViewDefinitionID,
        @GVCD_ColumnOrder,
        @GVCD_IsPrimaryKey,
        @GVCD_IsHidden,
        @GVCD_IsFiltered,
        @GVCD_IsCombo,
        @GVCD_DisplayFormat,
        @GVCD_Width,
        @GVCD_SourceLanguageLabelID,
        @GVCD_TopHeaderCategory,
        @GVCD_TopHeaderCategoryOrder,
        @GVCD_SourceRowId;
END;

CLOSE GridViewColumnDefinitions_Cursor;
DEALLOCATE GridViewColumnDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewColumnDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view column definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   11. Labels
   ========================================================= */

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyLabels',
    @StepStatus = N'Succeeded',
    @Message = N'Labels are applied through SCore.LanguageLabels and SCore.LanguageLabelTranslations handlers.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations"]}';

UPDATE SMigration.Metadata_Run
SET
    RunStatus = N'AppliedUiMetadata',
    AppliedOnUtc = SYSUTCDATETIME()
WHERE Guid = @RunGuid
  AND RowStatus NOT IN (0,254);

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyMetadataComplete',
    @StepStatus = N'Succeeded',
    @Message = N'Core and UI metadata apply handlers completed.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations","SCore.EntityDataTypes","SUserInterface.Icons","SCore.EntityTypes","SCore.EntityHobts","SUserInterface.DropDownListDefinitions","SCore.EntityPropertyGroups","SCore.EntityQueries","SCore.EntityProperties","SCore.EntityQueryParameters","SUserInterface.GridDefinitions","SUserInterface.GridViewDefinitions","SUserInterface.GridViewColumnDefinitions"]}';

COMMIT TRANSACTION;
END;

GO


/* ================================================================================================
   Latest metadata apply and stage/diff normalisation handlers
   ================================================================================================ */

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

/*
    CymBuild Metadata CI/CD
    Stage/Diff normalisation fix

    Purpose:
    - Keep raw SourcePayloadJson / TargetPayloadJson for audit.
    - Stop Stage/Diff reporting false inserts where Apply intentionally reuses
      an existing target row by natural key.
    - Stop Stage/Diff reporting false updates caused only by environment-specific
      numeric IDs/FKs.

    Required call point:
    - Execute SMigration.MetadataStage_NormaliseDifferences after all
      SMigration.Metadata_StagedRows have been inserted for a run and before
      SummaryJson is calculated/read by the UI.

    Works for:
    - same-server SQL proc staging
    - API two-connection staging, provided the API calls this proc after staging
*/

CREATE OR ALTER PROCEDURE [SMigration].[MetadataStage_NormaliseDifferences]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS
    (
        SELECT 1
        FROM SMigration.Metadata_Run AS r
        WHERE r.Guid = @RunGuid
          AND r.RowStatus NOT IN (0,254)
    )
    BEGIN
        THROW 53000, 'Metadata stage normalisation failed because the run was not found or is inactive.', 1;
    END;

    DECLARE
        @EntityPropertiesColumnList NVARCHAR(MAX),
        @GridViewColumnDefinitionsColumnList NVARCHAR(MAX),
        @IconsColumnList NVARCHAR(MAX),
        @Sql NVARCHAR(MAX);

    /* =========================================================
       1. Convert false inserts to natural-key target matches.
          These remain Update/NoChange based on the real target payload.
       ========================================================= */

    SELECT
        @EntityPropertiesColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'epj.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SCore'
      AND t.name = N'EntityProperties'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @EntityPropertiesColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH EntityPropertiesToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetEp.ID AS TargetEntityPropertyID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            TRY_CONVERT(BIGINT, COALESCE
            (
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHoBTID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHoBTId''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHobtID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.EntityHobtId'')
            )) AS SourceEntityHoBTID,
            JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS PropertyName
    ) AS parsed
    LEFT JOIN SMigration.Metadata_TableRegistry AS hobtReg
        ON hobtReg.SchemaName = N''SCore''
       AND hobtReg.TableName = N''EntityHobts''
       AND hobtReg.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_StagedRows AS srcHobt
        ON srcHobt.RunGuid = sr.RunGuid
       AND srcHobt.RegistryGuid = hobtReg.Guid
       AND srcHobt.SourceRowId = parsed.SourceEntityHoBTID
       AND srcHobt.RowStatus NOT IN (0,254)
    LEFT JOIN SCore.EntityHobts AS targetHobt
        ON targetHobt.Guid = srcHobt.SourceRowGuid
       AND targetHobt.RowStatus NOT IN (0,254)
    LEFT JOIN SCore.EntityProperties AS targetEp
        ON targetEp.EntityHoBTID = targetHobt.ID
       AND targetEp.Name = parsed.PropertyName
       AND targetEp.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SCore''
      AND tr.TableName = N''EntityProperties''
      AND targetEp.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN EntityPropertiesToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @EntityPropertiesColumnList + N'
            FROM SCore.EntityProperties AS epj
            WHERE epj.ID = n.TargetEntityPropertyID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    SELECT
        @GridViewColumnDefinitionsColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'gvcdj.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SUserInterface'
      AND t.name = N'GridViewColumnDefinitions'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @GridViewColumnDefinitionsColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH GridViewColumnsToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetCol.ID AS TargetGridViewColumnDefinitionID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT
            TRY_CONVERT(BIGINT, COALESCE
            (
                JSON_VALUE(sr.SourcePayloadJson, N''$.GridViewDefinitionID''),
                JSON_VALUE(sr.SourcePayloadJson, N''$.GridViewDefinitionId'')
            )) AS SourceGridViewDefinitionID,
            JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS ColumnName,
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N''$.IsPrimaryKey'')) AS IsPrimaryKey
    ) AS parsed
    LEFT JOIN SMigration.Metadata_TableRegistry AS gvdReg
        ON gvdReg.SchemaName = N''SUserInterface''
       AND gvdReg.TableName = N''GridViewDefinitions''
       AND gvdReg.RowStatus NOT IN (0,254)
    LEFT JOIN SMigration.Metadata_StagedRows AS srcGvd
        ON srcGvd.RunGuid = sr.RunGuid
       AND srcGvd.RegistryGuid = gvdReg.Guid
       AND srcGvd.SourceRowId = parsed.SourceGridViewDefinitionID
       AND srcGvd.RowStatus NOT IN (0,254)
    LEFT JOIN SUserInterface.GridViewDefinitions AS targetGvd
        ON targetGvd.Guid = srcGvd.SourceRowGuid
       AND targetGvd.RowStatus NOT IN (0,254)
    LEFT JOIN SUserInterface.GridViewColumnDefinitions AS targetCol
        ON targetCol.GridViewDefinitionID = targetGvd.ID
       AND targetCol.RowStatus NOT IN (0,254)
       AND
       (
            targetCol.Name = parsed.ColumnName
            OR
            (
                ISNULL(parsed.IsPrimaryKey, 0) = 1
                AND targetCol.IsPrimaryKey = 1
            )
       )
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SUserInterface''
      AND tr.TableName = N''GridViewColumnDefinitions''
      AND targetCol.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN GridViewColumnsToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @GridViewColumnDefinitionsColumnList + N'
            FROM SUserInterface.GridViewColumnDefinitions AS gvcdj
            WHERE gvcdj.ID = n.TargetGridViewColumnDefinitionID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    SELECT
        @IconsColumnList = STRING_AGG(CONVERT(NVARCHAR(MAX), N'ij.' + QUOTENAME(c.name)), N',')
            WITHIN GROUP (ORDER BY c.column_id)
    FROM sys.schemas AS s
    INNER JOIN sys.tables AS t
        ON t.schema_id = s.schema_id
    INNER JOIN sys.columns AS c
        ON c.object_id = t.object_id
    WHERE s.name = N'SUserInterface'
      AND t.name = N'Icons'
      AND c.is_computed = 0
      AND c.system_type_id <> 189;

    IF @IconsColumnList IS NOT NULL
    BEGIN
        SET @Sql = N'
;WITH IconsToNaturalise AS
(
    SELECT
        sr.ID AS StagedRowID,
        targetIcon.ID AS TargetIconID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY
    (
        SELECT JSON_VALUE(sr.SourcePayloadJson, N''$.Name'') AS IconName
    ) AS parsed
    LEFT JOIN SUserInterface.Icons AS targetIcon
        ON targetIcon.Name = parsed.IconName
       AND targetIcon.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N''Insert''
      AND tr.SchemaName = N''SUserInterface''
      AND tr.TableName = N''Icons''
      AND targetIcon.ID IS NOT NULL
)
UPDATE sr
SET
    TargetPayloadJson = tgt.TargetPayloadJson,
    TargetPayloadHash = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)),
    DifferenceType = CASE
        WHEN HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), sr.SourcePayloadJson))
           = HASHBYTES(''SHA2_256'', CONVERT(VARBINARY(MAX), tgt.TargetPayloadJson)) THEN N''NoChange''
        ELSE N''Update''
    END
FROM SMigration.Metadata_StagedRows AS sr
INNER JOIN IconsToNaturalise AS n
    ON n.StagedRowID = sr.ID
OUTER APPLY
(
    SELECT
        (
            SELECT ' + @IconsColumnList + N'
            FROM SUserInterface.Icons AS ij
            WHERE ij.ID = n.TargetIconID
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        ) AS TargetPayloadJson
) AS tgt
WHERE tgt.TargetPayloadJson IS NOT NULL;';

        EXEC sys.sp_executesql
            @Sql,
            N'@RunGuid UNIQUEIDENTIFIER',
            @RunGuid = @RunGuid;
    END;

    /* =========================================================
       2. Normalise false updates caused by environment-specific IDs.
          This keeps relationship drift visible only where a stable, non-ID
          metadata value differs. Raw payloads remain available for audit.
       ========================================================= */

    IF OBJECT_ID(N'tempdb..#MetadataNormalisedDiff') IS NOT NULL
        DROP TABLE #MetadataNormalisedDiff;

    CREATE TABLE #MetadataNormalisedDiff
    (
        StagedRowID BIGINT NOT NULL PRIMARY KEY,
        SourceNormalisedHash VARBINARY(32) NULL,
        TargetNormalisedHash VARBINARY(32) NULL
    );

    ;WITH SourceNormalised AS
    (
        SELECT
            sr.ID AS StagedRowID,
            HASHBYTES
            (
                'SHA2_256',
                CONVERT
                (
                    VARBINARY(MAX),
                    STRING_AGG
                    (
                        CONVERT(NVARCHAR(MAX), CONCAT(j.[key], N'=', ISNULL(j.[value], N'<NULL>'))),
                        N'|'
                    ) WITHIN GROUP (ORDER BY j.[key])
                )
            ) AS NormalisedHash
        FROM SMigration.Metadata_StagedRows AS sr
        CROSS APPLY OPENJSON(sr.SourcePayloadJson) AS j
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType = N'Update'
          AND sr.TargetPayloadJson IS NOT NULL
          AND j.[key] NOT IN
          (
              N'ID',
              N'EntityTypeID', N'EntityTypeId',
              N'EntityHoBTID', N'EntityHoBTId', N'EntityHobtID', N'EntityHobtId',
              N'LanguageLabelID', N'LanguageLabelId',
              N'LanguageID', N'LanguageId',
              N'EntityDataTypeID', N'EntityDataTypeId',
              N'EntityPropertyGroupID', N'EntityPropertyGroupId',
              N'DropDownListDefinitionID', N'DropDownListDefinitionId',
              N'EntityQueryID', N'EntityQueryId',
              N'MappedEntityPropertyID', N'MappedEntityPropertyId',
              N'GridDefinitionID', N'GridDefinitionId',
              N'GridViewDefinitionID', N'GridViewDefinitionId',
              N'MetricTypeID', N'MetricTypeId',
              N'DrawerIconID', N'DrawerIconId',
              N'GridViewTypeID', N'GridViewTypeId',
              N'IconID', N'IconId',
              N'PropertyGroupLayoutID', N'PropertyGroupLayoutId'
          )
        GROUP BY sr.ID
    ),
    TargetNormalised AS
    (
        SELECT
            sr.ID AS StagedRowID,
            HASHBYTES
            (
                'SHA2_256',
                CONVERT
                (
                    VARBINARY(MAX),
                    STRING_AGG
                    (
                        CONVERT(NVARCHAR(MAX), CONCAT(j.[key], N'=', ISNULL(j.[value], N'<NULL>'))),
                        N'|'
                    ) WITHIN GROUP (ORDER BY j.[key])
                )
            ) AS NormalisedHash
        FROM SMigration.Metadata_StagedRows AS sr
        CROSS APPLY OPENJSON(sr.TargetPayloadJson) AS j
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType = N'Update'
          AND sr.TargetPayloadJson IS NOT NULL
          AND j.[key] NOT IN
          (
              N'ID',
              N'EntityTypeID', N'EntityTypeId',
              N'EntityHoBTID', N'EntityHoBTId', N'EntityHobtID', N'EntityHobtId',
              N'LanguageLabelID', N'LanguageLabelId',
              N'LanguageID', N'LanguageId',
              N'EntityDataTypeID', N'EntityDataTypeId',
              N'EntityPropertyGroupID', N'EntityPropertyGroupId',
              N'DropDownListDefinitionID', N'DropDownListDefinitionId',
              N'EntityQueryID', N'EntityQueryId',
              N'MappedEntityPropertyID', N'MappedEntityPropertyId',
              N'GridDefinitionID', N'GridDefinitionId',
              N'GridViewDefinitionID', N'GridViewDefinitionId',
              N'MetricTypeID', N'MetricTypeId',
              N'DrawerIconID', N'DrawerIconId',
              N'GridViewTypeID', N'GridViewTypeId',
              N'IconID', N'IconId',
              N'PropertyGroupLayoutID', N'PropertyGroupLayoutId'
          )
        GROUP BY sr.ID
    )
    INSERT INTO #MetadataNormalisedDiff
    (
        StagedRowID,
        SourceNormalisedHash,
        TargetNormalisedHash
    )
    SELECT
        sr.ID,
        sn.NormalisedHash,
        tn.NormalisedHash
    FROM SMigration.Metadata_StagedRows AS sr
    LEFT JOIN SourceNormalised AS sn
        ON sn.StagedRowID = sr.ID
    LEFT JOIN TargetNormalised AS tn
        ON tn.StagedRowID = sr.ID
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL;

    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN #MetadataNormalisedDiff AS nd
        ON nd.StagedRowID = sr.ID
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND nd.SourceNormalisedHash = nd.TargetNormalisedHash;

    /* =========================================================
       3. Refresh run summary after normalisation.
       ========================================================= */

    UPDATE SMigration.Metadata_Run
    SET SummaryJson =
    (
        SELECT
            CONCAT
            (
                N'{"insertCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Insert' THEN 1 ELSE 0 END), 0)),
                N',"updateCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'Update' THEN 1 ELSE 0 END), 0)),
                N',"noChangeCount":',
                CONVERT(NVARCHAR(30), ISNULL(SUM(CASE WHEN sr.DifferenceType = N'NoChange' THEN 1 ELSE 0 END), 0)),
                N',"totalCount":',
                CONVERT(NVARCHAR(30), COUNT_BIG(1)),
                N'}'
            )
        FROM SMigration.Metadata_StagedRows AS sr
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
    )
    WHERE Guid = @RunGuid
      AND RowStatus NOT IN (0,254);
END;
GO

/*
    SAME-SERVER SQL STAGING INTEGRATION
    -----------------------------------
    In SMigration.MetadataStage_Run, call this procedure immediately before
    the SummaryJson update or replace the existing SummaryJson update with
    this call followed by the existing log entry:

        EXEC SMigration.MetadataStage_NormaliseDifferences
            @RunGuid = @RunGuid;

    API TWO-CONNECTION STAGING INTEGRATION
    --------------------------------------
    After the API has inserted staged rows and before the dashboard is read,
    execute the same stored procedure on the target connection:

        EXEC SMigration.MetadataStage_NormaliseDifferences @RunGuid = @RunGuid;
*/


/* ================================================================================================
   Latest metadata apply and stage/diff normalisation handlers
   ================================================================================================ */


SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataStage_NormaliseEnvironmentOnlyUpdates]
(
    @RunGuid UNIQUEIDENTIFIER
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    /*
        Converts staged rows from Update -> NoChange when the only changed JSON
        properties are environment-specific identity values:
          - ID / Guid
          - numeric FK columns whose target values legitimately differ between databases

        This does not alter SourcePayloadJson or TargetPayloadJson; it only suppresses
        false-positive DifferenceType values after the main stage comparison has already
        captured the full audit payloads.

        Do not suppress real SCore.EntityQueries.Statement changes. Statements are only
        considered equal when their aggressively normalised content matches.
    */

    ------------------------------------------------------------
    -- SCore.EntityProperties
    ------------------------------------------------------------
    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityProperties'
      AND NOT EXISTS
      (
          SELECT 1
          FROM OPENJSON(sr.SourcePayloadJson) AS src
          FULL OUTER JOIN OPENJSON(sr.TargetPayloadJson) AS tgt
              ON tgt.[key] COLLATE DATABASE_DEFAULT = src.[key] COLLATE DATABASE_DEFAULT
          WHERE ISNULL(CONVERT(NVARCHAR(MAX), src.[value]), N'') COLLATE DATABASE_DEFAULT
              <> ISNULL(CONVERT(NVARCHAR(MAX), tgt.[value]), N'') COLLATE DATABASE_DEFAULT
            AND COALESCE(src.[key], tgt.[key]) COLLATE DATABASE_DEFAULT NOT IN
            (
                N'ID',
                N'Guid',
                N'RowVersion',
                N'LanguageLabelID',
                N'LanguageLabelId',
                N'EntityHoBTID',
                N'EntityHoBTId',
                N'EntityHobtID',
                N'EntityHobtId',
                N'EntityDataTypeID',
                N'EntityDataTypeId',
                N'EntityPropertyGroupID',
                N'EntityPropertyGroupId',
                N'DropDownListDefinitionID',
                N'DropDownListDefinitionId'
            )
      );

    ------------------------------------------------------------
    -- SCore.EntityQueries
    ------------------------------------------------------------
    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        Statement NVARCHAR(MAX) N'$.Statement'
    ) AS srcStmt
    OUTER APPLY OPENJSON(sr.TargetPayloadJson)
    WITH
    (
        Statement NVARCHAR(MAX) N'$.Statement'
    ) AS tgtStmt
    CROSS APPLY
    (
        SELECT
            LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                ISNULL(srcStmt.Statement, N''),
                CHAR(13), N''), CHAR(10), N''), CHAR(9), N''), NCHAR(160), N''), N' ', N''), N'"', N''
            )) AS NormalisedSourceStatement,
            LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                ISNULL(tgtStmt.Statement, N''),
                CHAR(13), N''), CHAR(10), N''), CHAR(9), N''), NCHAR(160), N''), N' ', N''), N'"', N''
            )) AS NormalisedTargetStatement
    ) AS stmt
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueries'
      AND NOT EXISTS
      (
          SELECT 1
          FROM OPENJSON(sr.SourcePayloadJson) AS src
          FULL OUTER JOIN OPENJSON(sr.TargetPayloadJson) AS tgt
              ON tgt.[key] COLLATE DATABASE_DEFAULT = src.[key] COLLATE DATABASE_DEFAULT
          WHERE ISNULL(CONVERT(NVARCHAR(MAX), src.[value]), N'') COLLATE DATABASE_DEFAULT
              <> ISNULL(CONVERT(NVARCHAR(MAX), tgt.[value]), N'') COLLATE DATABASE_DEFAULT
            AND COALESCE(src.[key], tgt.[key]) COLLATE DATABASE_DEFAULT NOT IN
            (
                N'ID',
                N'Guid',
                N'RowVersion',
                N'EntityTypeID',
                N'EntityTypeId',
                N'EntityHoBTID',
                N'EntityHoBTId',
                N'EntityHobtID',
                N'EntityHobtId',
                N'Statement'
            )
      )
      AND stmt.NormalisedSourceStatement = stmt.NormalisedTargetStatement;

    ------------------------------------------------------------
    -- SUserInterface.GridViewColumnDefinitions
    ------------------------------------------------------------
    UPDATE sr
    SET DifferenceType = N'NoChange'
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType = N'Update'
      AND sr.TargetPayloadJson IS NOT NULL
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
      AND NOT EXISTS
      (
          SELECT 1
          FROM OPENJSON(sr.SourcePayloadJson) AS src
          FULL OUTER JOIN OPENJSON(sr.TargetPayloadJson) AS tgt
              ON tgt.[key] COLLATE DATABASE_DEFAULT = src.[key] COLLATE DATABASE_DEFAULT
          WHERE ISNULL(CONVERT(NVARCHAR(MAX), src.[value]), N'') COLLATE DATABASE_DEFAULT
              <> ISNULL(CONVERT(NVARCHAR(MAX), tgt.[value]), N'') COLLATE DATABASE_DEFAULT
            AND COALESCE(src.[key], tgt.[key]) COLLATE DATABASE_DEFAULT NOT IN
            (
                N'ID',
                N'Guid',
                N'RowVersion',
                N'GridViewDefinitionID',
                N'GridViewDefinitionId',
                N'LanguageLabelID',
                N'LanguageLabelId'
            )
      );
END;
GO
/* CI/CD-safe idempotent SMigration metadata run selection deployment.
   R2: persisted cherry-pick selections plus selected-only apply support.
*/
SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    EXEC(N'CREATE SCHEMA [SMigration] AUTHORIZATION [dbo];');
GO

IF OBJECT_ID(N'SMigration.Metadata_RunSelections', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Metadata_RunSelections]
    (
        [ID] [bigint] IDENTITY(1,1) NOT NULL,
        [Guid] [uniqueidentifier] NOT NULL,
        [RowStatus] [tinyint] NOT NULL,
        [RunGuid] [uniqueidentifier] NOT NULL,
        [RegistryGuid] [uniqueidentifier] NOT NULL,
        [SourceRowGuid] [uniqueidentifier] NOT NULL,
        [DifferenceType] [nvarchar](30) NOT NULL,
        [SelectionSource] [nvarchar](30) NOT NULL,
        [SelectedByUserId] [int] NOT NULL,
        [SelectedOnUtc] [datetime2](7) NOT NULL,
        CONSTRAINT [PK_Metadata_RunSelections] PRIMARY KEY CLUSTERED ([ID] ASC) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Metadata_RunSelections_Guid] UNIQUE NONCLUSTERED ([Guid] ASC) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Metadata_RunSelections_Run_Table_Row] UNIQUE NONCLUSTERED ([RunGuid] ASC, [RegistryGuid] ASC, [SourceRowGuid] ASC) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY];
END;
GO

IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_RunSelections_RowStatus' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections'))
    ALTER TABLE [SMigration].[Metadata_RunSelections] ADD CONSTRAINT [DF_Metadata_RunSelections_RowStatus] DEFAULT (1) FOR [RowStatus];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_RunSelections_SelectionSource' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections'))
    ALTER TABLE [SMigration].[Metadata_RunSelections] ADD CONSTRAINT [DF_Metadata_RunSelections_SelectionSource] DEFAULT (N'Manual') FOR [SelectionSource];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_RunSelections_SelectedByUserId' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections'))
    ALTER TABLE [SMigration].[Metadata_RunSelections] ADD CONSTRAINT [DF_Metadata_RunSelections_SelectedByUserId] DEFAULT (-1) FOR [SelectedByUserId];
GO
IF NOT EXISTS (SELECT 1 FROM sys.default_constraints WHERE name = N'DF_Metadata_RunSelections_SelectedOnUtc' AND parent_object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections'))
    ALTER TABLE [SMigration].[Metadata_RunSelections] ADD CONSTRAINT [DF_Metadata_RunSelections_SelectedOnUtc] DEFAULT (SYSUTCDATETIME()) FOR [SelectedOnUtc];
GO
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = N'IX_Metadata_RunSelections_RunGuid' AND object_id = OBJECT_ID(N'SMigration.Metadata_RunSelections'))
BEGIN
    CREATE INDEX [IX_Metadata_RunSelections_RunGuid]
      ON [SMigration].[Metadata_RunSelections] ([RunGuid], [RegistryGuid], [DifferenceType])
      WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
      WITH (FILLFACTOR = 80)
      ON [PRIMARY];
END;
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_Upsert]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRunSelection_Upsert]
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

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_Clear]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRunSelection_Clear]
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

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApply_Run]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApply_Run]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ForceApply BIT = 0,
    @ApplySelectedOnly BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RunStatus NVARCHAR(30),
        @TargetEnvironment NVARCHAR(20),
        @SourceDatabaseName SYSNAME,
        @FailCount INT = 0,
        @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    SELECT
        @RunStatus = r.RunStatus,
        @TargetEnvironment = r.TargetEnvironment,
        @SourceDatabaseName = r.SourceDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @RunStatus IS NULL
        THROW 52000, 'Metadata run was not found or is inactive.', 1;

    IF @RunStatus NOT IN
    (
        N'Validated',
        N'PartiallyApplied',
        N'AppliedCoreMetadata',
        N'AppliedUiMetadata'
    )
        THROW 52001, 'Metadata run must be Validated, PartiallyApplied, AppliedCoreMetadata or AppliedUiMetadata before apply.', 1;

    SELECT
        @FailCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi
    INNER JOIN SMigration.Metadata_Run AS runScope
        ON runScope.Guid = vi.RunGuid
       AND runScope.RowStatus NOT IN (0,254)
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored
          WHERE ignored.DatabaseName = runScope.TargetDatabaseName
            AND ignored.RegistryGuid = vi.RegistryGuid
            AND ignored.SourceRowGuid = vi.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      );

    IF ISNULL(@FailCount, 0) > 0
        THROW 52002, 'Metadata run has validation failures and cannot be applied.', 1;

    IF @TargetEnvironment = N'LIVE' AND ISNULL(@ForceApply, 0) = 0
        THROW 52003, 'LIVE metadata apply requires @ForceApply = 1.', 1;

    BEGIN TRANSACTION;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyStart',
        @StepStatus = N'Started',
        @Message = N'Metadata apply started.',
        @DetailsJson = N'{}';

    
    IF OBJECT_ID(N'tempdb..#MetadataSourceGuidLookup') IS NOT NULL
        DROP TABLE #MetadataSourceGuidLookup;

    CREATE TABLE #MetadataSourceGuidLookup
    (
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        SourceRowId BIGINT NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_MetadataSourceGuidLookup PRIMARY KEY CLUSTERED
        (
            SchemaName,
            TableName,
            SourceRowId
        )
    );

    INSERT INTO #MetadataSourceGuidLookup
    (
        SchemaName,
        TableName,
        SourceRowId,
        SourceRowGuid
    )
    SELECT
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowId,
        sr.SourceRowGuid
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.SourceRowId IS NOT NULL
      AND sr.SourceRowGuid IS NOT NULL;

    IF OBJECT_ID(N'tempdb..#MetadataRowsToApply') IS NOT NULL
        DROP TABLE #MetadataRowsToApply;

    CREATE TABLE #MetadataRowsToApply
    (
        StagedRowId BIGINT NOT NULL,
        CONSTRAINT PK_MetadataRowsToApply PRIMARY KEY CLUSTERED (StagedRowId)
    );

    INSERT INTO #MetadataRowsToApply
    (
        StagedRowId
    )
    SELECT
        sr.ID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_Run AS runScope
        ON runScope.Guid = sr.RunGuid
       AND runScope.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored
          WHERE ignored.DatabaseName = runScope.TargetDatabaseName
            AND ignored.RegistryGuid = sr.RegistryGuid
            AND ignored.SourceRowGuid = sr.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      )
      AND
      (
          ISNULL(@ApplySelectedOnly, 0) = 0
          OR EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS sel
              WHERE sel.RunGuid = sr.RunGuid
                AND sel.RegistryGuid = sr.RegistryGuid
                AND sel.SourceRowGuid = sr.SourceRowGuid
                AND sel.RowStatus NOT IN (0,254)
          )
      );

    IF ISNULL(@ApplySelectedOnly, 0) = 1
       AND NOT EXISTS (SELECT 1 FROM #MetadataRowsToApply)
        THROW 52004, 'Apply selected requires at least one selected Insert or Update metadata row.', 1;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplySelectionScope',
        @StepStatus = N'Succeeded',
        @Message = CASE WHEN ISNULL(@ApplySelectedOnly, 0) = 1 THEN N'Metadata apply scoped to selected rows.' ELSE N'Metadata apply scoped to all valid rows.' END,
        @DetailsJson =
        (
            SELECT
                ISNULL(@ApplySelectedOnly, 0) AS applySelectedOnly,
                COUNT_BIG(1) AS rowCount
            FROM #MetadataRowsToApply
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );
/* =========================================================
       1. SCore.LanguageLabels
       ========================================================= */
    DECLARE
        @Guid UNIQUEIDENTIFIER,
        @Name NVARCHAR(500);

    DECLARE LanguageLabels_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name')
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'LanguageLabels'
        ORDER BY sr.SourceRowId;

    OPEN LanguageLabels_Cursor;

    FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelUpsert
            @Name = @Name,
            @Guid = @LanguageLabelGuid OUTPUT;

        FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;
    END;

    CLOSE LanguageLabels_Cursor;
    DEALLOCATE LanguageLabels_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabels',
        @StepStatus = N'Succeeded',
        @Message = N'Language labels applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       2. SCore.LanguageLabelTranslations
       ========================================================= */
    DECLARE
        @Text NVARCHAR(500),
        @TextPlural NVARCHAR(500),
        @HelpText NVARCHAR(MAX),
        @LanguageLabelGuidRef UNIQUEIDENTIFIER,
        @LanguageGuidRef UNIQUEIDENTIFIER,
        @SourceLanguageLabelId BIGINT,
        @SourceLanguageId BIGINT,
        @Sql NVARCHAR(MAX);

    IF OBJECT_ID(N'tempdb..#LanguageLabelTranslationsToApply') IS NOT NULL
        DROP TABLE #LanguageLabelTranslationsToApply;

    CREATE TABLE #LanguageLabelTranslationsToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        Text NVARCHAR(500) NULL,
        TextPlural NVARCHAR(500) NULL,
        HelpText NVARCHAR(MAX) NULL,
        SourceLanguageLabelId BIGINT NULL,
        SourceLanguageId BIGINT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #LanguageLabelTranslationsToApply
    (
        Guid,
        Text,
        TextPlural,
        HelpText,
        SourceLanguageLabelId,
        SourceLanguageId,
        SourceRowId
    )
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Text'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TextPlural'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.HelpText'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageId'))),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'LanguageLabelTranslations';

    DECLARE LanguageLabelTranslations_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            Text,
            TextPlural,
            HelpText,
            SourceLanguageLabelId,
            SourceLanguageId
        FROM #LanguageLabelTranslationsToApply
        ORDER BY SourceRowId;

    OPEN LanguageLabelTranslations_Cursor;

    FETCH NEXT FROM LanguageLabelTranslations_Cursor
    INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @LanguageLabelGuidRef = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'LanguageLabels'
          AND lookup.SourceRowId = @SourceLanguageLabelId;

        SELECT
            @LanguageGuidRef = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'Languages'
          AND lookup.SourceRowId = @SourceLanguageId;

        DECLARE @LanguageLabelTranslationGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelTranslationUpsert
            @Text = @Text,
            @TextPlural = @TextPlural,
            @HelpText = @HelpText,
            @LanguageLabelGuid = @LanguageLabelGuidRef,
            @LanguageGuid = @LanguageGuidRef,
            @Guid = @LanguageLabelTranslationGuid OUTPUT;

        FETCH NEXT FROM LanguageLabelTranslations_Cursor
        INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;
    END;

    CLOSE LanguageLabelTranslations_Cursor;
    DEALLOCATE LanguageLabelTranslations_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabelTranslations',
        @StepStatus = N'Succeeded',
        @Message = N'Language label translations applied.',
        @DetailsJson = N'{}';


    
/* =========================================================
       3. SCore.EntityDataTypes
       Required reference metadata for EntityProperties and EntityQueryParameters.
       No dedicated EntityDataTypeUpsert exists in the current schema, so this
       handler uses SCore.UpsertDataObject and explicit idempotent DML.
       ========================================================= */
    DECLARE
        @EDT_RowStatus TINYINT,
        @EDT_Name NVARCHAR(250),
        @EDT_QuoteValue BIT,
        @EDT_IsInsert BIT;

    DECLARE EntityDataTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.QuoteValue'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityDataTypes'
        ORDER BY sr.SourceRowId;

    OPEN EntityDataTypes_Cursor;

    FETCH NEXT FROM EntityDataTypes_Cursor
    INTO
        @Guid,
        @EDT_RowStatus,
        @EDT_Name,
        @EDT_QuoteValue;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EDT_IsInsert = 0;

        EXEC SCore.UpsertDataObject
            @Guid = @Guid,
            @SchemeName = N'SCore',
            @ObjectName = N'EntityDataTypes',
            @IsInsert = @EDT_IsInsert OUTPUT;

        IF @EDT_IsInsert = 1
        BEGIN
            INSERT INTO SCore.EntityDataTypes
            (
                Guid,
                RowStatus,
                Name,
                QuoteValue
            )
            VALUES
            (
                @Guid,
                ISNULL(NULLIF(@EDT_RowStatus, 0), 1),
                ISNULL(@EDT_Name, N''),
                ISNULL(@EDT_QuoteValue, 0)
            );
        END;
        ELSE
        BEGIN
            UPDATE SCore.EntityDataTypes
            SET
                RowStatus = ISNULL(NULLIF(@EDT_RowStatus, 0), RowStatus),
                Name = ISNULL(@EDT_Name, N''),
                QuoteValue = ISNULL(@EDT_QuoteValue, 0)
            WHERE Guid = @Guid;
        END;

        FETCH NEXT FROM EntityDataTypes_Cursor
        INTO
            @Guid,
            @EDT_RowStatus,
            @EDT_Name,
            @EDT_QuoteValue;
    END;

    CLOSE EntityDataTypes_Cursor;
    DEALLOCATE EntityDataTypes_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityDataTypes',
        @StepStatus = N'Succeeded',
        @Message = N'Entity data types applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       4. SUserInterface.Icons
       Required reference metadata for EntityTypes and GridViewDefinitions.
       No dedicated IconUpsert exists in the current schema, so this
       handler uses SCore.UpsertDataObject and explicit idempotent DML.
       Natural key fallback is Name to avoid duplicate icon CSS classes.
       ========================================================= */
    DECLARE
        @ICON_RowStatus TINYINT,
        @ICON_Name NVARCHAR(50),
        @ICON_SourceRowId BIGINT,
        @ICON_IsInsert BIT,
        @ICON_ExistingGuid UNIQUEIDENTIFIER,
        @ICON_GuidToApply UNIQUEIDENTIFIER;

    DECLARE Icons_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            sr.SourceRowId
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SUserInterface'
          AND tr.TableName = N'Icons'
        ORDER BY sr.SourceRowId;

    OPEN Icons_Cursor;

    FETCH NEXT FROM Icons_Cursor
    INTO
        @Guid,
        @ICON_RowStatus,
        @ICON_Name,
        @ICON_SourceRowId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ICON_ExistingGuid = NULL;
        SET @ICON_GuidToApply = @Guid;
        SET @ICON_IsInsert = 0;

        SELECT TOP (1)
            @ICON_ExistingGuid = i.Guid
        FROM SUserInterface.Icons AS i
        WHERE i.Name = ISNULL(@ICON_Name, N'')
          AND i.RowStatus NOT IN (0,254)
          AND i.Guid <> @Guid
        ORDER BY i.ID;

        IF @ICON_ExistingGuid IS NOT NULL
        BEGIN
            SET @ICON_GuidToApply = @ICON_ExistingGuid;

            UPDATE lookup
            SET SourceRowGuid = @ICON_ExistingGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SUserInterface'
              AND lookup.TableName = N'Icons'
              AND lookup.SourceRowId = @ICON_SourceRowId;
        END;

        EXEC SCore.UpsertDataObject
            @Guid = @ICON_GuidToApply,
            @SchemeName = N'SUserInterface',
            @ObjectName = N'Icons',
            @IsInsert = @ICON_IsInsert OUTPUT;

        IF @ICON_IsInsert = 1
        BEGIN
            INSERT INTO SUserInterface.Icons
            (
                Guid,
                RowStatus,
                Name
            )
            VALUES
            (
                @ICON_GuidToApply,
                ISNULL(NULLIF(@ICON_RowStatus, 0), 1),
                ISNULL(@ICON_Name, N'')
            );
        END;
        ELSE
        BEGIN
            UPDATE SUserInterface.Icons
            SET
                RowStatus = ISNULL(NULLIF(@ICON_RowStatus, 0), RowStatus),
                Name = ISNULL(@ICON_Name, N'')
            WHERE Guid = @ICON_GuidToApply;
        END;

        FETCH NEXT FROM Icons_Cursor
        INTO
            @Guid,
            @ICON_RowStatus,
            @ICON_Name,
            @ICON_SourceRowId;
    END;

    CLOSE Icons_Cursor;
    DEALLOCATE Icons_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyIcons',
        @StepStatus = N'Succeeded',
        @Message = N'Icons applied.',
        @DetailsJson = N'{}';


/* =========================================================
       3. SCore.EntityTypes
       Required reference metadata for EntityQueries/GridViews/DropDownLists.
       Applies staged EntityTypes before dependent metadata.
       ========================================================= */
    DECLARE
        @ET_RowStatus TINYINT,
        @ET_IsReadOnlyOffline BIT,
        @ET_IsRequiredSystemData BIT,
        @ET_HasDocuments BIT,
        @ET_SourceLanguageLabelID BIGINT,
        @ET_DoNotTrackChanges BIT,
        @ET_SourceIconID BIGINT,
        @ET_IsRootEntity BIT,
        @ET_DetailPageUrl NVARCHAR(250),
        @ET_IsMetaData BIT,
        @ET_IsDeletable BIT,
        @ET_LanguageLabelGuid UNIQUEIDENTIFIER,
        @ET_IconGuid UNIQUEIDENTIFIER;

    DECLARE EntityTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsRequiredSystemData')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasDocuments')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.IconID'), JSON_VALUE(sr.SourcePayloadJson, N'$.IconId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsRootEntity')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMetaData')),
            ISNULL(TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDeletable')), 1)
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityTypes'
        ORDER BY sr.SourceRowId;

    OPEN EntityTypes_Cursor;

    FETCH NEXT FROM EntityTypes_Cursor
    INTO
        @Guid,
        @ET_RowStatus,
        @Name,
        @ET_IsReadOnlyOffline,
        @ET_IsRequiredSystemData,
        @ET_HasDocuments,
        @ET_SourceLanguageLabelID,
        @ET_DoNotTrackChanges,
        @ET_SourceIconID,
        @ET_IsRootEntity,
        @ET_DetailPageUrl,
            @ET_IsMetaData,
            @ET_IsDeletable;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ET_LanguageLabelGuid = NULL;
        SET @ET_IconGuid = NULL;

        SELECT
            @ET_LanguageLabelGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'LanguageLabels'
          AND lookup.SourceRowId = @ET_SourceLanguageLabelID;

        SELECT
            @ET_IconGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'Icons'
          AND lookup.SourceRowId = @ET_SourceIconID;

        DECLARE @EntityTypeGuidToApply UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityTypeUpsert
            @Name = @Name,
            @RowStatus = @ET_RowStatus,
            @IsReadOnlyOffline = @ET_IsReadOnlyOffline,
            @IsRequiredSystemData = @ET_IsRequiredSystemData,
            @HasDocuments = @ET_HasDocuments,
            @LanguageLabelGuid = @ET_LanguageLabelGuid,
            @DoNotTrackChanges = @ET_DoNotTrackChanges,
            @IconGuid = @ET_IconGuid,
            @IsRootEntity = @ET_IsRootEntity,
            @DetailPageUrl = @ET_DetailPageUrl,
            @IsMetaData = @ET_IsMetaData,
            @IsDeletable = @ET_IsDeletable,
            @Guid = @EntityTypeGuidToApply OUTPUT;

        FETCH NEXT FROM EntityTypes_Cursor
        INTO
            @Guid,
            @ET_RowStatus,
            @Name,
            @ET_IsReadOnlyOffline,
            @ET_IsRequiredSystemData,
            @ET_HasDocuments,
            @ET_SourceLanguageLabelID,
            @ET_DoNotTrackChanges,
            @ET_SourceIconID,
            @ET_IsRootEntity,
            @ET_DetailPageUrl,
            @ET_IsMetaData,
            @ET_IsDeletable;
    END;

    CLOSE EntityTypes_Cursor;
    DEALLOCATE EntityTypes_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityTypes',
        @StepStatus = N'Succeeded',
        @Message = N'Entity types applied.',
        @DetailsJson = N'{}';


    /* =========================================================
       4. SCore.EntityHobts
       Required reference metadata for EntityQueries and EntityProperties.
       Applies staged HoBTs after EntityTypes and before dependent metadata.
       ========================================================= */
    DECLARE
        @EH_RowStatus TINYINT,
        @EH_SchemaName NVARCHAR(250),
        @EH_ObjectName NVARCHAR(250),
        @EH_SourceEntityTypeID BIGINT,
        @EH_ObjectType NVARCHAR(1),
        @EH_IsMainHoBT BIT,
        @EH_IsReadOnlyOffline BIT,
        @EH_EntityTypeGuid UNIQUEIDENTIFIER;

    DECLARE EntityHobts_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectType'), N'T'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMainHoBT')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityHobts'
        ORDER BY sr.SourceRowId;

    OPEN EntityHobts_Cursor;

    FETCH NEXT FROM EntityHobts_Cursor
    INTO
        @Guid,
        @EH_RowStatus,
        @EH_SchemaName,
        @EH_ObjectName,
        @EH_SourceEntityTypeID,
        @EH_ObjectType,
        @EH_IsMainHoBT,
        @EH_IsReadOnlyOffline;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EH_EntityTypeGuid = NULL;

        SELECT
            @EH_EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @EH_SourceEntityTypeID;

        IF @EH_EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingHoBTEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityHobts apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EH_SourceEntityTypeID), N'<NULL>'), N' for HoBT ', COALESCE(@EH_SchemaName + N'.' + @EH_ObjectName, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityHobts.');
            THROW 52021, @MissingHoBTEntityTypeMessage, 1;
        END;

        DECLARE @EntityHoBTGuidToApply UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityHoBTUpsert
            @SchemaName = @EH_SchemaName,
            @ObjectName = @EH_ObjectName,
            @ObjectType = @EH_ObjectType,
            @IsMainHoBT = @EH_IsMainHoBT,
            @IsReadOnlyOffline = @EH_IsReadOnlyOffline,
            @EntityTypeGuid = @EH_EntityTypeGuid,
            @Guid = @EntityHoBTGuidToApply OUTPUT;

        FETCH NEXT FROM EntityHobts_Cursor
        INTO
            @Guid,
            @EH_RowStatus,
            @EH_SchemaName,
            @EH_ObjectName,
            @EH_SourceEntityTypeID,
            @EH_ObjectType,
            @EH_IsMainHoBT,
            @EH_IsReadOnlyOffline;
    END;

    CLOSE EntityHobts_Cursor;
    DEALLOCATE EntityHobts_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityHobts',
        @StepStatus = N'Succeeded',
        @Message = N'Entity HoBTs applied.',
        @DetailsJson = N'{}';

    /* =========================================================
   10. SUserInterface.DropDownListDefinitions
   ========================================================= */

DECLARE
    @DDL_Code NVARCHAR(20),
    @DDL_NameColumn NVARCHAR(254),
    @DDL_ValueColumn NVARCHAR(254),
    @DDL_SqlQuery NVARCHAR(MAX),
    @DDL_DefaultSortColumnName NVARCHAR(254),
    @DDL_IsDefaultColumn BIT,
    @DDL_IsDetailWindowed BIT,
    @DDL_DetailPageURI NVARCHAR(250),
    @DDL_SourceEntityTypeID BIGINT,
    @DDL_InformationPageURI NVARCHAR(250),
    @DDL_GroupColumn NVARCHAR(254),
    @DDL_ColourHexColumn NVARCHAR(7),
    @DDL_ExternalSearchPageUrl NVARCHAR(250),
    @DDL_EntityTypeGuid UNIQUEIDENTIFIER;

DECLARE DropDownListDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.NameColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ValueColumn'),
        ddlJsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultColumn')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.InformationPageUrl'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.GroupColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ColourHexColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ExternalSearchPageUrl')
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery'
    ) AS ddlJsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'DropDownListDefinitions'
    ORDER BY sr.SourceRowId;

OPEN DropDownListDefinitions_Cursor;

FETCH NEXT FROM DropDownListDefinitions_Cursor
INTO
    @Guid,
    @DDL_Code,
    @DDL_NameColumn,
    @DDL_ValueColumn,
    @DDL_SqlQuery,
    @DDL_DefaultSortColumnName,
    @DDL_IsDefaultColumn,
    @DDL_IsDetailWindowed,
    @DDL_DetailPageURI,
    @DDL_SourceEntityTypeID,
    @DDL_InformationPageURI,
    @DDL_GroupColumn,
    @DDL_ColourHexColumn,
    @DDL_ExternalSearchPageUrl;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DDL_EntityTypeGuid = NULL;
    IF @DDL_SourceEntityTypeID IS NULL OR @DDL_SourceEntityTypeID <= 0
    BEGIN
        SET @DDL_EntityTypeGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @DDL_EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @DDL_SourceEntityTypeID;
    END;

    IF @DDL_EntityTypeGuid IS NULL
    BEGIN
        DECLARE @MissingDDLTargetEntityTypeMessage NVARCHAR(4000) = CONCAT(N'DropDownListDefinitions apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @DDL_SourceEntityTypeID), N'<NULL>'), N' for drop-down list ', COALESCE(@DDL_Code, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SUserInterface.DropDownListDefinitions.');
        THROW 52028, @MissingDDLTargetEntityTypeMessage, 1;
    END;

    DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.DropDownListDefinitionUpsert
        @Code = @DDL_Code,
        @NameColumn = @DDL_NameColumn,
        @ValueColumn = @DDL_ValueColumn,
        @SqlQuery = @DDL_SqlQuery,
        @DefaultSortColumnName = @DDL_DefaultSortColumnName,
        @IsDefaultColumn = @DDL_IsDefaultColumn,
        @IsDetailWindowed = @DDL_IsDetailWindowed,
        @DetailPageURI = @DDL_DetailPageURI,
        @EntityTypeGuid = @DDL_EntityTypeGuid,
        @InformationPageURI = @DDL_InformationPageURI,
        @GroupColumn = @DDL_GroupColumn,
        @Guid = @DropDownListDefinitionGuid OUTPUT,
        @ColourHexColumn = @DDL_ColourHexColumn,
        @ExternalSearchPageUrl = @DDL_ExternalSearchPageUrl;

    FETCH NEXT FROM DropDownListDefinitions_Cursor
    INTO
        @Guid,
        @DDL_Code,
        @DDL_NameColumn,
        @DDL_ValueColumn,
        @DDL_SqlQuery,
        @DDL_DefaultSortColumnName,
        @DDL_IsDefaultColumn,
        @DDL_IsDetailWindowed,
        @DDL_DetailPageURI,
        @DDL_SourceEntityTypeID,
        @DDL_InformationPageURI,
        @DDL_GroupColumn,
        @DDL_ColourHexColumn,
        @DDL_ExternalSearchPageUrl;
END;

CLOSE DropDownListDefinitions_Cursor;
DEALLOCATE DropDownListDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyDropDownListDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Drop-down list definitions applied.',
    @DetailsJson = N'{}';


/* =========================================================
       8. SCore.EntityPropertyGroups
       Required reference metadata for EntityProperties.
       ========================================================= */
    DECLARE
        @EPG_RowStatus TINYINT,
        @EPG_Name NVARCHAR(250),
        @EPG_IsHidden BIT,
        @EPG_SortOrder INT,
        @EPG_SourceLanguageLabelID BIGINT,
        @EPG_SourceEntityTypeID BIGINT,
        @EPG_SourcePropertyGroupLayoutID BIGINT,
        @EPG_ShowOnMobile BIT,
        @EPG_IsCollapsable BIT,
        @EPG_IsDefaultCollapsed BIT,
        @EPG_IsDefaultCollapsed_Mobile BIT,
        @EPG_LanguageLabelGuid UNIQUEIDENTIFIER,
        @EPG_EntityTypeGuid UNIQUEIDENTIFIER,
        @EPG_PropertyGroupLayoutGuid UNIQUEIDENTIFIER;

    DECLARE EntityPropertyGroups_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
            TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.PropertyGroupLayoutID'), JSON_VALUE(sr.SourcePayloadJson, N'$.PropertyGroupLayoutId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCollapsable')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed_Mobile'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityPropertyGroups'
        ORDER BY sr.SourceRowId;

    OPEN EntityPropertyGroups_Cursor;

    FETCH NEXT FROM EntityPropertyGroups_Cursor
    INTO
        @Guid,
        @EPG_RowStatus,
        @EPG_Name,
        @EPG_IsHidden,
        @EPG_SortOrder,
        @EPG_SourceLanguageLabelID,
        @EPG_SourceEntityTypeID,
        @EPG_SourcePropertyGroupLayoutID,
        @EPG_ShowOnMobile,
        @EPG_IsCollapsable,
        @EPG_IsDefaultCollapsed,
        @EPG_IsDefaultCollapsed_Mobile;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EPG_LanguageLabelGuid = NULL;
        SET @EPG_EntityTypeGuid = NULL;
        SET @EPG_PropertyGroupLayoutGuid = NULL;

        IF @EPG_SourceLanguageLabelID IS NULL OR @EPG_SourceLanguageLabelID <= 0
        BEGIN
            SET @EPG_LanguageLabelGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_LanguageLabelGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SCore'
              AND lookup.TableName = N'LanguageLabels'
              AND lookup.SourceRowId = @EPG_SourceLanguageLabelID;
        END;

        IF @EPG_SourceEntityTypeID IS NULL OR @EPG_SourceEntityTypeID <= 0
        BEGIN
            SET @EPG_EntityTypeGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_EntityTypeGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SCore'
              AND lookup.TableName = N'EntityTypes'
              AND lookup.SourceRowId = @EPG_SourceEntityTypeID;
        END;

        IF @EPG_SourcePropertyGroupLayoutID IS NULL OR @EPG_SourcePropertyGroupLayoutID <= 0
        BEGIN
            SET @EPG_PropertyGroupLayoutGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_PropertyGroupLayoutGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SUserInterface'
              AND lookup.TableName = N'PropertyGroupLayouts'
              AND lookup.SourceRowId = @EPG_SourcePropertyGroupLayoutID;
        END;

        IF @EPG_LanguageLabelGuid IS NULL
        BEGIN
            DECLARE @MissingEPGLanguageLabelMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve LanguageLabel source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourceLanguageLabelID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.LanguageLabels is staged/applied before SCore.EntityPropertyGroups.');
            THROW 52025, @MissingEPGLanguageLabelMessage, 1;
        END;

        IF @EPG_EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingEPGEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourceEntityTypeID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityPropertyGroups.');
            THROW 52026, @MissingEPGEntityTypeMessage, 1;
        END;

        IF @EPG_PropertyGroupLayoutGuid IS NULL
        BEGIN
            DECLARE @MissingEPGLayoutMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve PropertyGroupLayout source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourcePropertyGroupLayoutID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SUserInterface.PropertyGroupLayouts is included as reference metadata if this is not the zero/default layout.');
            THROW 52027, @MissingEPGLayoutMessage, 1;
        END;

        DECLARE @EntityPropertyGroupGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityPropertyGroupUpsert
            @Name = @EPG_Name,
            @RowStatus = @EPG_RowStatus,
            @IsHidden = @EPG_IsHidden,
            @SortOrder = @EPG_SortOrder,
            @LanguageLabelGuid = @EPG_LanguageLabelGuid,
            @EntityTypeGuid = @EPG_EntityTypeGuid,
            @PropertyGroupLayoutGuid = @EPG_PropertyGroupLayoutGuid,
            @ShowOnMobile = @EPG_ShowOnMobile,
            @IsCollapsable = @EPG_IsCollapsable,
            @IsDefaultCollapsed = @EPG_IsDefaultCollapsed,
            @IsDefaultCollapsed_Mobile = @EPG_IsDefaultCollapsed_Mobile,
            @Guid = @EntityPropertyGroupGuid OUTPUT;

        FETCH NEXT FROM EntityPropertyGroups_Cursor
        INTO
            @Guid,
            @EPG_RowStatus,
            @EPG_Name,
            @EPG_IsHidden,
            @EPG_SortOrder,
            @EPG_SourceLanguageLabelID,
            @EPG_SourceEntityTypeID,
            @EPG_SourcePropertyGroupLayoutID,
            @EPG_ShowOnMobile,
            @EPG_IsCollapsable,
            @EPG_IsDefaultCollapsed,
            @EPG_IsDefaultCollapsed_Mobile;
    END;

    CLOSE EntityPropertyGroups_Cursor;
    DEALLOCATE EntityPropertyGroups_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityPropertyGroups',
        @StepStatus = N'Succeeded',
        @Message = N'Entity property groups applied.',
        @DetailsJson = N'{}';

/* =========================================================
       5. SCore.EntityQueries
       ========================================================= */
    DECLARE
        @Statement NVARCHAR(MAX),
        @EntityTypeGuid UNIQUEIDENTIFIER,
        @EntityHoBTGuid UNIQUEIDENTIFIER,
        @IsDefaultCreate BIT,
        @IsDefaultRead BIT,
        @IsDefaultUpdate BIT,
        @IsDefaultDelete BIT,
        @IsScalarExecute BIT,
        @IsDefaultValidation BIT,
        @IsDefaultDataPills BIT,
        @IsMergeDocumentQuery BIT,
        @IsProgressData BIT,
        @SchemaName NVARCHAR(255),
        @ObjectName NVARCHAR(255),
        @IsManualStatement BIT,
        @RowStatus TINYINT,
        @SourceEntityTypeId BIGINT,
        @SourceEntityHoBTId BIGINT;

    IF OBJECT_ID(N'tempdb..#EntityQueriesToApply') IS NOT NULL
        DROP TABLE #EntityQueriesToApply;

    CREATE TABLE #EntityQueriesToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        RowStatus TINYINT NULL,
        Name NVARCHAR(500) NULL,
        Statement NVARCHAR(MAX) NULL,
        SourceEntityTypeId BIGINT NULL,
        SourceEntityHoBTId BIGINT NULL,
        IsDefaultCreate BIT NULL,
        IsDefaultRead BIT NULL,
        IsDefaultUpdate BIT NULL,
        IsDefaultDelete BIT NULL,
        IsScalarExecute BIT NULL,
        IsDefaultValidation BIT NULL,
        IsDefaultDataPills BIT NULL,
        IsMergeDocumentQuery BIT NULL,
        IsProgressData BIT NULL,
        SchemaName NVARCHAR(255) NULL,
        ObjectName NVARCHAR(255) NULL,
        IsManualStatement BIT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #EntityQueriesToApply
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        jsonPayload.Statement,
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTId'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtId'))),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCreate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultRead')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultUpdate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDelete')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsScalarExecute')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultValidation')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDataPills')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMergeDocumentQuery')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsProgressData')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsManualStatement')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        Statement NVARCHAR(MAX) N'$.Statement'
    ) AS jsonPayload
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueries';

    DECLARE EntityQueries_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            RowStatus,
            Name,
            Statement,
            SourceEntityTypeId,
            SourceEntityHoBTId,
            IsDefaultCreate,
            IsDefaultRead,
            IsDefaultUpdate,
            IsDefaultDelete,
            IsScalarExecute,
            IsDefaultValidation,
            IsDefaultDataPills,
            IsMergeDocumentQuery,
            IsProgressData,
            SchemaName,
            ObjectName,
            IsManualStatement
        FROM #EntityQueriesToApply
        ORDER BY SourceRowId;

    OPEN EntityQueries_Cursor;

    FETCH NEXT FROM EntityQueries_Cursor
    INTO
        @Guid,
        @RowStatus,
        @Name,
        @Statement,
        @SourceEntityTypeId,
        @SourceEntityHoBTId,
        @IsDefaultCreate,
        @IsDefaultRead,
        @IsDefaultUpdate,
        @IsDefaultDelete,
        @IsScalarExecute,
        @IsDefaultValidation,
        @IsDefaultDataPills,
        @IsMergeDocumentQuery,
        @IsProgressData,
        @SchemaName,
        @ObjectName,
        @IsManualStatement;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EntityTypeGuid = NULL;
        SET @EntityHoBTGuid = NULL;

        SELECT
            @EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @SourceEntityTypeId;

        SELECT
            @EntityHoBTGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityHobts'
          AND lookup.SourceRowId = @SourceEntityHoBTId;

        IF @EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityQueries apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @SourceEntityTypeId), N'<NULL>'), N' for query ', COALESCE(@Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityQueries.');
            THROW 52020, @MissingEntityTypeMessage, 1;
        END;

        DECLARE @EntityQueryGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityQueryUpsert
            @Name = @Name,
            @RowStatus = @RowStatus,
            @Statement = @Statement,
            @EntityTypeGuid = @EntityTypeGuid,
            @IsDefaultCreate = @IsDefaultCreate,
            @IsDefaultRead = @IsDefaultRead,
            @IsDefaultUpdate = @IsDefaultUpdate,
            @IsDefaultDelete = @IsDefaultDelete,
            @IsScalarExecute = @IsScalarExecute,
            @IsDefaultValidation = @IsDefaultValidation,
            @EntityHoBTGuid = @EntityHoBTGuid,
            @IsDefaultDataPills = @IsDefaultDataPills,
            @IsMergeDocumentQuery = @IsMergeDocumentQuery,
            @IsProgressData = @IsProgressData,
            @SchemaName = @SchemaName,
            @ObjectName = @ObjectName,
            @IsManualStatement = @IsManualStatement,
            @Guid = @EntityQueryGuid OUTPUT;

        FETCH NEXT FROM EntityQueries_Cursor
        INTO
            @Guid,
            @RowStatus,
            @Name,
            @Statement,
            @SourceEntityTypeId,
            @SourceEntityHoBTId,
            @IsDefaultCreate,
            @IsDefaultRead,
            @IsDefaultUpdate,
            @IsDefaultDelete,
            @IsScalarExecute,
            @IsDefaultValidation,
            @IsDefaultDataPills,
            @IsMergeDocumentQuery,
            @IsProgressData,
            @SchemaName,
            @ObjectName,
            @IsManualStatement;
    END;

    CLOSE EntityQueries_Cursor;
    DEALLOCATE EntityQueries_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityQueries',
        @StepStatus = N'Succeeded',
        @Message = N'Entity queries applied.',
        @DetailsJson = N'{}';

/* =========================================================
   5. SCore.EntityProperties
   ========================================================= */

DECLARE
    @EP_RowStatus TINYINT,
    @EP_Name NVARCHAR(500),
    @EP_SourceLanguageLabelID BIGINT,
    @EP_SourceEntityHoBTID BIGINT,
    @EP_SourceEntityDataTypeID BIGINT,
    @EP_SourceEntityPropertyGroupID BIGINT,
    @EP_SourceDropDownListDefinitionID BIGINT,
    @EP_SourceRowId BIGINT,
    @EP_LanguageLabelGuid UNIQUEIDENTIFIER,
    @EP_EntityHoBTGuid UNIQUEIDENTIFIER,
    @EP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EP_EntityPropertyGroupGuid UNIQUEIDENTIFIER,
    @EP_DropDownListDefinitionGuid UNIQUEIDENTIFIER,
    @EP_IsReadOnly BIT,
    @EP_IsImmutable BIT,
    @EP_IsUppercase BIT,
    @EP_IsHidden BIT,
    @EP_IsCompulsory BIT,
    @EP_MaxLength INT,
    @EP_Precision INT,
    @EP_Scale INT,
    @EP_DoNotTrackChanges BIT,
    @EP_SortOrder SMALLINT,
    @EP_GroupSortOrder SMALLINT,
    @EP_IsObjectLabel BIT,
    @EP_IsParentRelationship BIT,
    @EP_IsIncludedInformation BIT,
    @EP_IsLatitude BIT,
    @EP_IsLongitude BIT,
    @EP_FixDefaultValue NVARCHAR(100),
    @EP_SqlDefaultValueStatement NVARCHAR(MAX),
    @EP_AllowBulkChange BIT,
    @EP_IsVirtual BIT,
    @EP_ShowOnMobile BIT,
    @EP_IsAlwaysVisibleInGroup BIT,
    @EP_IsAlwaysVisibleInGroup_Mobile BIT;

IF OBJECT_ID(N'tempdb..#EntityPropertiesToApply') IS NOT NULL
    DROP TABLE #EntityPropertiesToApply;

CREATE TABLE #EntityPropertiesToApply
(
    Guid UNIQUEIDENTIFIER NOT NULL,
    RowStatus TINYINT NULL,
    Name NVARCHAR(500) NULL,
    SourceLanguageLabelID BIGINT NULL,
    SourceEntityHoBTID BIGINT NULL,
    SourceEntityDataTypeID BIGINT NULL,
    IsReadOnly BIT NULL,
    IsImmutable BIT NULL,
    IsUppercase BIT NULL,
    IsHidden BIT NULL,
    IsCompulsory BIT NULL,
    MaxLength INT NULL,
    PrecisionValue INT NULL,
    ScaleValue INT NULL,
    DoNotTrackChanges BIT NULL,
    SourceEntityPropertyGroupID BIGINT NULL,
    SortOrder SMALLINT NULL,
    GroupSortOrder SMALLINT NULL,
    IsObjectLabel BIT NULL,
    SourceDropDownListDefinitionID BIGINT NULL,
    IsParentRelationship BIT NULL,
    IsIncludedInformation BIT NULL,
    IsLatitude BIT NULL,
    IsLongitude BIT NULL,
    FixDefaultValue NVARCHAR(100) NULL,
    SqlDefaultValueStatement NVARCHAR(MAX) NULL,
    AllowBulkChange BIT NULL,
    IsVirtual BIT NULL,
    ShowOnMobile BIT NULL,
    IsAlwaysVisibleInGroup BIT NULL,
    IsAlwaysVisibleInGroup_Mobile BIT NULL,
    SourceRowId BIGINT NULL
);

INSERT INTO #EntityPropertiesToApply
SELECT
    sr.SourceRowGuid,
    TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
    JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTId'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtId'))),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeId'))),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnly')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsImmutable')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsUppercase')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCompulsory')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MaxLength')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Precision')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Scale')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupId'))),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GroupSortOrder')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsObjectLabel')),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionId'))),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsParentRelationship')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsIncludedInformation')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLatitude')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLongitude')),
    ISNULL
    (
        COALESCE
        (
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixedDefaultValue'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixDefaultValue')
        ),
        N''
    ),
    epjson.SqlDefaultValueStatement,
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsVirtual')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup_Mobile')),
    sr.SourceRowId
FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
INNER JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = sr.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
OUTER APPLY OPENJSON(sr.SourcePayloadJson)
WITH
(
    SqlDefaultValueStatement NVARCHAR(MAX) N'$.SqlDefaultValueStatement'
) AS epjson
WHERE sr.RunGuid = @RunGuid
  AND sr.RowStatus NOT IN (0,254)
  AND sr.DifferenceType IN (N'Insert', N'Update')
  AND tr.SchemaName = N'SCore'
  AND tr.TableName = N'EntityProperties';

DECLARE EntityProperties_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        Guid,
        RowStatus,
        Name,
        SourceLanguageLabelID,
        SourceEntityHoBTID,
        SourceEntityDataTypeID,
        IsReadOnly,
        IsImmutable,
        IsUppercase,
        IsHidden,
        IsCompulsory,
        MaxLength,
        PrecisionValue,
        ScaleValue,
        DoNotTrackChanges,
        SourceEntityPropertyGroupID,
        SortOrder,
        GroupSortOrder,
        IsObjectLabel,
        SourceDropDownListDefinitionID,
        IsParentRelationship,
        IsIncludedInformation,
        IsLatitude,
        IsLongitude,
        FixDefaultValue,
        SqlDefaultValueStatement,
        AllowBulkChange,
        IsVirtual,
        ShowOnMobile,
        IsAlwaysVisibleInGroup,
        IsAlwaysVisibleInGroup_Mobile,
        SourceRowId
    FROM #EntityPropertiesToApply
    ORDER BY SourceRowId;

OPEN EntityProperties_Cursor;

FETCH NEXT FROM EntityProperties_Cursor
INTO
    @Guid,
    @EP_RowStatus,
    @EP_Name,
    @EP_SourceLanguageLabelID,
    @EP_SourceEntityHoBTID,
    @EP_SourceEntityDataTypeID,
    @EP_IsReadOnly,
    @EP_IsImmutable,
    @EP_IsUppercase,
    @EP_IsHidden,
    @EP_IsCompulsory,
    @EP_MaxLength,
    @EP_Precision,
    @EP_Scale,
    @EP_DoNotTrackChanges,
    @EP_SourceEntityPropertyGroupID,
    @EP_SortOrder,
    @EP_GroupSortOrder,
    @EP_IsObjectLabel,
    @EP_SourceDropDownListDefinitionID,
    @EP_IsParentRelationship,
    @EP_IsIncludedInformation,
    @EP_IsLatitude,
    @EP_IsLongitude,
    @EP_FixDefaultValue,
    @EP_SqlDefaultValueStatement,
    @EP_AllowBulkChange,
    @EP_IsVirtual,
    @EP_ShowOnMobile,
    @EP_IsAlwaysVisibleInGroup,
    @EP_IsAlwaysVisibleInGroup_Mobile,
    @EP_SourceRowId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EP_LanguageLabelGuid = NULL;
    SET @EP_EntityHoBTGuid = NULL;
    SET @EP_EntityDataTypeGuid = NULL;
    SET @EP_EntityPropertyGroupGuid = NULL;
    SET @EP_DropDownListDefinitionGuid = NULL;
    SET @EP_FixDefaultValue = ISNULL(@EP_FixDefaultValue, N'');
    SELECT
        @EP_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @EP_SourceLanguageLabelID;

    SELECT
        @EP_EntityHoBTGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityHobts'
      AND lookup.SourceRowId = @EP_SourceEntityHoBTID;

    IF @EP_SourceEntityDataTypeID IS NULL OR @EP_SourceEntityDataTypeID <= 0
    BEGIN
        SET @EP_EntityDataTypeGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_EntityDataTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityDataTypes'
          AND lookup.SourceRowId = @EP_SourceEntityDataTypeID;
    END;

    IF @EP_SourceEntityPropertyGroupID IS NULL OR @EP_SourceEntityPropertyGroupID <= 0
    BEGIN
        SET @EP_EntityPropertyGroupGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_EntityPropertyGroupGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityPropertyGroups'
          AND lookup.SourceRowId = @EP_SourceEntityPropertyGroupID;
    END;

    IF @EP_SourceDropDownListDefinitionID IS NULL OR @EP_SourceDropDownListDefinitionID <= 0
    BEGIN
        SET @EP_DropDownListDefinitionGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_DropDownListDefinitionGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'DropDownListDefinitions'
          AND lookup.SourceRowId = @EP_SourceDropDownListDefinitionID;
    END;

    IF @EP_EntityDataTypeGuid IS NULL
    BEGIN
        DECLARE @MissingEntityDataTypeMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityDataType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityDataTypeID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityDataTypes is staged/applied before SCore.EntityProperties.');
        THROW 52022, @MissingEntityDataTypeMessage, 1;
    END;

    IF @EP_EntityPropertyGroupGuid IS NULL
    BEGIN
        DECLARE @MissingEntityPropertyGroupMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityPropertyGroup source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityPropertyGroupID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityPropertyGroups is staged/applied before SCore.EntityProperties.');
        THROW 52023, @MissingEntityPropertyGroupMessage, 1;
    END;

    IF @EP_DropDownListDefinitionGuid IS NULL
    BEGIN
        DECLARE @MissingDropDownListDefinitionMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve DropDownListDefinition source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceDropDownListDefinitionID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SUserInterface.DropDownListDefinitions is applied before SCore.EntityProperties.');
        THROW 52024, @MissingDropDownListDefinitionMessage, 1;
    END;

    DECLARE @ExistingEntityPropertyGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @ExistingEntityPropertyGuid = ep.Guid
    FROM SCore.EntityProperties AS ep
    INNER JOIN SCore.EntityHobts AS eh
        ON eh.ID = ep.EntityHoBTID
       AND eh.RowStatus NOT IN (0,254)
    WHERE eh.Guid = @EP_EntityHoBTGuid
      AND ep.Name = @EP_Name
      AND ep.RowStatus NOT IN (0,254)
      AND ep.Guid <> @Guid
    ORDER BY ep.ID;

    DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER = ISNULL(@ExistingEntityPropertyGuid, @Guid);

    IF @ExistingEntityPropertyGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingEntityPropertyGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityProperties'
          AND lookup.SourceRowId = @EP_SourceRowId;
    END;

    EXEC SCore.EntityPropertyUpsert
        @Name = @EP_Name,
        @RowStatus = @EP_RowStatus,
        @LanguageLabelGuid = @EP_LanguageLabelGuid,
        @EntityHobtGuid = @EP_EntityHoBTGuid,
        @EntityDataTypeGuid = @EP_EntityDataTypeGuid,
        @IsReadOnly = @EP_IsReadOnly,
        @IsImmutable = @EP_IsImmutable,
        @IsUppercase = @EP_IsUppercase,
        @IsHidden = @EP_IsHidden,
        @IsCompulsory = @EP_IsCompulsory,
        @MaxLength = @EP_MaxLength,
        @Precision = @EP_Precision,
        @Scale = @EP_Scale,
        @DoNotTrackChanges = @EP_DoNotTrackChanges,
        @EntityPropertyGroupGuid = @EP_EntityPropertyGroupGuid,
        @SortOrder = @EP_SortOrder,
        @GroupSortOrder = @EP_GroupSortOrder,
        @IsObjectLabel = @EP_IsObjectLabel,
        @DropDownListDefinitionGuid = @EP_DropDownListDefinitionGuid,
        @IsParentRelationship = @EP_IsParentRelationship,
        @IsIncludedInformation = @EP_IsIncludedInformation,
        @IsLatitude = @EP_IsLatitude,
        @IsLongitude = @EP_IsLongitude,
        @FixDefaultValue = @EP_FixDefaultValue,
        @SqlDefaultValueStatement = @EP_SqlDefaultValueStatement,
        @AllowBulkChange = @EP_AllowBulkChange,
        @IsVirtual = @EP_IsVirtual,
        @ShowOnMobile = @EP_ShowOnMobile,
        @IsAlwaysVisibleInGroup = @EP_IsAlwaysVisibleInGroup,
        @IsAlwaysVisibleInGroup_Mobile = @EP_IsAlwaysVisibleInGroup_Mobile,
        @Guid = @EntityPropertyGuid OUTPUT;

    FETCH NEXT FROM EntityProperties_Cursor
    INTO
        @Guid,
        @EP_RowStatus,
        @EP_Name,
        @EP_SourceLanguageLabelID,
        @EP_SourceEntityHoBTID,
        @EP_SourceEntityDataTypeID,
        @EP_IsReadOnly,
        @EP_IsImmutable,
        @EP_IsUppercase,
        @EP_IsHidden,
        @EP_IsCompulsory,
        @EP_MaxLength,
        @EP_Precision,
        @EP_Scale,
        @EP_DoNotTrackChanges,
        @EP_SourceEntityPropertyGroupID,
        @EP_SortOrder,
        @EP_GroupSortOrder,
        @EP_IsObjectLabel,
        @EP_SourceDropDownListDefinitionID,
        @EP_IsParentRelationship,
        @EP_IsIncludedInformation,
        @EP_IsLatitude,
        @EP_IsLongitude,
        @EP_FixDefaultValue,
        @EP_SqlDefaultValueStatement,
        @EP_AllowBulkChange,
        @EP_IsVirtual,
        @EP_ShowOnMobile,
        @EP_IsAlwaysVisibleInGroup,
        @EP_IsAlwaysVisibleInGroup_Mobile,
        @EP_SourceRowId;
END;

CLOSE EntityProperties_Cursor;
DEALLOCATE EntityProperties_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityProperties',
    @StepStatus = N'Succeeded',
    @Message = N'Entity properties applied.',
    @DetailsJson = N'{}';

/* =========================================================
   6. SCore.EntityQueryParameters
   ========================================================= */

DECLARE
    @EQP_RowStatus TINYINT,
    @EQP_Name NVARCHAR(500),
    @EQP_SourceEntityQueryID BIGINT,
    @EQP_SourceEntityDataTypeID BIGINT,
    @EQP_SourceMappedEntityPropertyID BIGINT,
    @EQP_EntityQueryGuid UNIQUEIDENTIFIER,
    @EQP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EQP_MappedEntityPropertyGuid UNIQUEIDENTIFIER,
    @EQP_DefaultValue NVARCHAR(200),
    @EQP_IsInput BIT,
    @EQP_IsOutput BIT,
    @EQP_IsReturnColumn BIT;

DECLARE EntityQueryParameters_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyID'), JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultValue'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsInput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsOutput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReturnColumn'))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueryParameters'
    ORDER BY sr.SourceRowId;

OPEN EntityQueryParameters_Cursor;

FETCH NEXT FROM EntityQueryParameters_Cursor
INTO
    @Guid,
    @EQP_RowStatus,
    @EQP_Name,
    @EQP_SourceEntityQueryID,
    @EQP_SourceEntityDataTypeID,
    @EQP_SourceMappedEntityPropertyID,
    @EQP_DefaultValue,
    @EQP_IsInput,
    @EQP_IsOutput,
    @EQP_IsReturnColumn;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EQP_EntityQueryGuid = NULL;
    SET @EQP_EntityDataTypeGuid = NULL;
    SET @EQP_MappedEntityPropertyGuid = NULL;
    SELECT
        @EQP_EntityQueryGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityQueries'
      AND lookup.SourceRowId = @EQP_SourceEntityQueryID;

    SELECT
        @EQP_EntityDataTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityDataTypes'
      AND lookup.SourceRowId = @EQP_SourceEntityDataTypeID;

    SELECT
        @EQP_MappedEntityPropertyGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityProperties'
      AND lookup.SourceRowId = @EQP_SourceMappedEntityPropertyID;

    DECLARE @EntityQueryParameterGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SCore.EntityQueryParameterUpsert
        @Name = @EQP_Name,
        @RowStatus = @EQP_RowStatus,
        @EntityQueryGuid = @EQP_EntityQueryGuid,
        @EntityDataTypeGuid = @EQP_EntityDataTypeGuid,
        @MappedEntityPropertyGuid = @EQP_MappedEntityPropertyGuid,
        @DefaultValue = @EQP_DefaultValue,
        @IsInput = @EQP_IsInput,
        @IsOutput = @EQP_IsOutput,
        @IsReturnColumn = @EQP_IsReturnColumn,
        @Guid = @EntityQueryParameterGuid OUTPUT;

    FETCH NEXT FROM EntityQueryParameters_Cursor
    INTO
        @Guid,
        @EQP_RowStatus,
        @EQP_Name,
        @EQP_SourceEntityQueryID,
        @EQP_SourceEntityDataTypeID,
        @EQP_SourceMappedEntityPropertyID,
        @EQP_DefaultValue,
        @EQP_IsInput,
        @EQP_IsOutput,
        @EQP_IsReturnColumn;
END;

CLOSE EntityQueryParameters_Cursor;
DEALLOCATE EntityQueryParameters_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityQueryParameters',
    @StepStatus = N'Succeeded',
    @Message = N'Entity query parameters applied.',
    @DetailsJson = N'{}';


/* =========================================================
   7. SUserInterface.GridDefinitions
   ========================================================= */

DECLARE
    @GD_RowStatus TINYINT,
    @GD_Code NVARCHAR(30),
    @GD_TabName NVARCHAR(250),
    @GD_ShowAsTiles BIT,
    @GD_PageUri NVARCHAR(250),
    @GD_SourceLanguageLabelID BIGINT,
    @GD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TabName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowAsTiles')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.PageUri'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId')))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridDefinitions_Cursor;

FETCH NEXT FROM GridDefinitions_Cursor
INTO
    @Guid,
    @GD_RowStatus,
    @GD_Code,
    @GD_TabName,
    @GD_ShowAsTiles,
    @GD_PageUri,
    @GD_SourceLanguageLabelID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GD_LanguageLabelGuid = NULL;
    SELECT
        @GD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GD_SourceLanguageLabelID;

    DECLARE @GridDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridDefinitionUpsert
        @Code = @GD_Code,
        @RowStatus = @GD_RowStatus,
        @TabName = @GD_TabName,
        @ShowAsTiles = @GD_ShowAsTiles,
        @PageUri = @GD_PageUri,
        @LanguageLabelGuid = @GD_LanguageLabelGuid,
        @Guid = @GridDefinitionGuid OUTPUT;

    FETCH NEXT FROM GridDefinitions_Cursor
    INTO
        @Guid,
        @GD_RowStatus,
        @GD_Code,
        @GD_TabName,
        @GD_ShowAsTiles,
        @GD_PageUri,
        @GD_SourceLanguageLabelID;
END;

CLOSE GridDefinitions_Cursor;
DEALLOCATE GridDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   8. SUserInterface.GridViewDefinitions
   ========================================================= */

DECLARE
    @GVD_RowStatus TINYINT,
    @GVD_Code NVARCHAR(20),
    @GVD_SourceGridDefinitionID BIGINT,
    @GVD_DetailPageUri NVARCHAR(250),
    @GVD_SqlQuery NVARCHAR(MAX),
    @GVD_DefaultSortColumnName NVARCHAR(250),
    @GVD_SecurableCode NVARCHAR(20),
    @GVD_DisplayOrder INT,
    @GVD_DisplayGroupName NVARCHAR(50),
    @GVD_MetricSqlQuery NVARCHAR(MAX),
    @GVD_ShowMetric BIT,
    @GVD_IsDetailWindowed BIT,
    @GVD_SourceEntityTypeID BIGINT,
    @GVD_SourceMetricTypeID BIGINT,
    @GVD_MetricMin INT,
    @GVD_MetricMax INT,
    @GVD_MetricMinorUnit INT,
    @GVD_MetricMajorUnit INT,
    @GVD_MetricStartAngle INT,
    @GVD_MetricEndAngle INT,
    @GVD_MetricReversed BIT,
    @GVD_MetricRange1Min DECIMAL(18,0),
    @GVD_MetricRange1Max DECIMAL(18,0),
    @GVD_MetricRange1ColourHex NVARCHAR(10),
    @GVD_MetricRange2Min DECIMAL(18,0),
    @GVD_MetricRange2Max DECIMAL(18,0),
    @GVD_MetricRange2ColourHex NVARCHAR(10),
    @GVD_IsDefaultSortDescending BIT,
    @GVD_ShowOnMobile BIT,
    @GVD_AllowNew BIT,
    @GVD_AllowExcelExport BIT,
    @GVD_AllowPdfExport BIT,
    @GVD_AllowCsvExport BIT,
    @GVD_SourceLanguageLabelID BIGINT,
    @GVD_SourceDrawerIconID BIGINT,
    @GVD_SourceGridViewTypeID BIGINT,
    @GVD_AllowBulkChange BIT,
    @GVD_TreeListFirstOrderBy NVARCHAR(100),
    @GVD_TreeListSecondOrderBy NVARCHAR(100),
    @GVD_TreeListThirdOrderBy NVARCHAR(100),
    @GVD_TreeListOrderBy NVARCHAR(100),
    @GVD_TreeListGroupBy NVARCHAR(100),
    @GVD_ShowOnDashboard BIT,
    @GVD_FilteredListCreatedOnColumn NVARCHAR(100),
    @GVD_FilteredListRedStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListOrangeStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGreenStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGroupBy NVARCHAR(100),
    @GVD_IsHidden BIT,
    @GVD_GridDefinitionGuid UNIQUEIDENTIFIER,
    @GVD_EntityTypeGuid UNIQUEIDENTIFIER,
    @GVD_MetricTypeGuid UNIQUEIDENTIFIER,
    @GVD_LanguageLabelGuid UNIQUEIDENTIFIER,
    @GVD_DrawerIconGuid UNIQUEIDENTIFIER,
    @GVD_GridViewTypeGuid UNIQUEIDENTIFIER;

DECLARE GridViewDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUri'),
        jsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SecurableCode'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayOrder')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayGroupName'),
        jsonValues.MetricSqlQuery,
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowMetric')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeId'))),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMin')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMax')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMinorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMajorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricStartAngle')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricEndAngle')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricReversed')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1ColourHex'),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2ColourHex'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultSortDescending')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowNew')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowExcelExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowPdfExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowCsvExport')),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconID'), JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeId'))),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListFirstOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListSecondOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListThirdOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnDashboard')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListCreatedOnColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListRedStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListOrangeStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGreenStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden'))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery',
        MetricSqlQuery NVARCHAR(MAX) N'$.MetricSqlQuery'
    ) AS jsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewDefinitions_Cursor;

FETCH NEXT FROM GridViewDefinitions_Cursor
INTO
    @Guid,
    @GVD_RowStatus,
    @GVD_Code,
    @GVD_SourceGridDefinitionID,
    @GVD_DetailPageUri,
    @GVD_SqlQuery,
    @GVD_DefaultSortColumnName,
    @GVD_SecurableCode,
    @GVD_DisplayOrder,
    @GVD_DisplayGroupName,
    @GVD_MetricSqlQuery,
    @GVD_ShowMetric,
    @GVD_IsDetailWindowed,
    @GVD_SourceEntityTypeID,
    @GVD_SourceMetricTypeID,
    @GVD_MetricMin,
    @GVD_MetricMax,
    @GVD_MetricMinorUnit,
    @GVD_MetricMajorUnit,
    @GVD_MetricStartAngle,
    @GVD_MetricEndAngle,
    @GVD_MetricReversed,
    @GVD_MetricRange1Min,
    @GVD_MetricRange1Max,
    @GVD_MetricRange1ColourHex,
    @GVD_MetricRange2Min,
    @GVD_MetricRange2Max,
    @GVD_MetricRange2ColourHex,
    @GVD_IsDefaultSortDescending,
    @GVD_ShowOnMobile,
    @GVD_AllowNew,
    @GVD_AllowExcelExport,
    @GVD_AllowPdfExport,
    @GVD_AllowCsvExport,
    @GVD_SourceLanguageLabelID,
    @GVD_SourceDrawerIconID,
    @GVD_SourceGridViewTypeID,
    @GVD_AllowBulkChange,
    @GVD_TreeListFirstOrderBy,
    @GVD_TreeListSecondOrderBy,
    @GVD_TreeListThirdOrderBy,
    @GVD_TreeListOrderBy,
    @GVD_TreeListGroupBy,
    @GVD_ShowOnDashboard,
    @GVD_FilteredListCreatedOnColumn,
    @GVD_FilteredListRedStatusIndicatorTxt,
    @GVD_FilteredListOrangeStatusIndicatorTxt,
    @GVD_FilteredListGreenStatusIndicatorTxt,
    @GVD_FilteredListGroupBy,
    @GVD_IsHidden;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVD_GridDefinitionGuid = NULL;
    SET @GVD_EntityTypeGuid = NULL;
    SET @GVD_MetricTypeGuid = NULL;
    SET @GVD_LanguageLabelGuid = NULL;
    SET @GVD_DrawerIconGuid = NULL;
    SET @GVD_GridViewTypeGuid = NULL;
    SELECT
        @GVD_GridDefinitionGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridDefinitions'
      AND lookup.SourceRowId = @GVD_SourceGridDefinitionID;

    SELECT
        @GVD_EntityTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityTypes'
      AND lookup.SourceRowId = @GVD_SourceEntityTypeID;

    SELECT
        @GVD_MetricTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'MetricTypes'
      AND lookup.SourceRowId = @GVD_SourceMetricTypeID;

    SELECT
        @GVD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GVD_SourceLanguageLabelID;

    SELECT
        @GVD_DrawerIconGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'Icons'
      AND lookup.SourceRowId = @GVD_SourceDrawerIconID;

    SELECT
        @GVD_GridViewTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridViewTypes'
      AND lookup.SourceRowId = @GVD_SourceGridViewTypeID;

    DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridViewDefinitionUpsert
        @Code = @GVD_Code,
        @RowStatus = @GVD_RowStatus,
        @GridDefinitionGuid = @GVD_GridDefinitionGuid,
        @DetailPageUri = @GVD_DetailPageUri,
        @SqlQuery = @GVD_SqlQuery,
        @DefaultSortColumnName = @GVD_DefaultSortColumnName,
        @SecurableCode = @GVD_SecurableCode,
        @DisplayOrder = @GVD_DisplayOrder,
        @DisplayGroupName = @GVD_DisplayGroupName,
        @MetricSqlQuery = @GVD_MetricSqlQuery,
        @ShowMetric = @GVD_ShowMetric,
        @IsDetailWindowed = @GVD_IsDetailWindowed,
        @EntityTypeGuid = @GVD_EntityTypeGuid,
        @MetricTypeGuid = @GVD_MetricTypeGuid,
        @MetricMin = @GVD_MetricMin,
        @MetricMax = @GVD_MetricMax,
        @MetricMinorUnit = @GVD_MetricMinorUnit,
        @MetricMajorUnit = @GVD_MetricMajorUnit,
        @MetricStartAngle = @GVD_MetricStartAngle,
        @MetricEndAngle = @GVD_MetricEndAngle,
        @MetricReversed = @GVD_MetricReversed,
        @MetricRange1Min = @GVD_MetricRange1Min,
        @MetricRange1Max = @GVD_MetricRange1Max,
        @MetricRange1ColourHex = @GVD_MetricRange1ColourHex,
        @MetricRange2Min = @GVD_MetricRange2Min,
        @MetricRange2Max = @GVD_MetricRange2Max,
        @MetricRange2ColourHex = @GVD_MetricRange2ColourHex,
        @IsDefaultSortDescending = @GVD_IsDefaultSortDescending,
        @AllowNew = @GVD_AllowNew,
        @AllowExcelExport = @GVD_AllowExcelExport,
        @AllowPdfExport = @GVD_AllowPdfExport,
        @AllowCsvExport = @GVD_AllowCsvExport,
        @LanguageLabelGuid = @GVD_LanguageLabelGuid,
        @DrawerIconGuid = @GVD_DrawerIconGuid,
        @GridViewTypeGuid = @GVD_GridViewTypeGuid,
        @AllowBulkChange = @GVD_AllowBulkChange,
        @Guid = @GridViewDefinitionGuid OUTPUT,
        @ShowOnMobile = @GVD_ShowOnMobile,
        @TreeListFirstOrderBy = @GVD_TreeListFirstOrderBy,
        @TreeListSecondOrderBy = @GVD_TreeListSecondOrderBy,
        @TreeListThirdOrderBy = @GVD_TreeListThirdOrderBy,
        @TreeListOrderBy = @GVD_TreeListOrderBy,
        @TreeListGroupBy = @GVD_TreeListGroupBy,
        @ShowOnDashboard = @GVD_ShowOnDashboard,
        @FilteredListCreatedOnColumn = @GVD_FilteredListCreatedOnColumn,
        @FilteredListRedStatusIndicatorTxt = @GVD_FilteredListRedStatusIndicatorTxt,
        @FilteredListOrangeStatusIndicatorTxt = @GVD_FilteredListOrangeStatusIndicatorTxt,
        @FilteredListGreenStatusIndicatorTxt = @GVD_FilteredListGreenStatusIndicatorTxt,
        @FilteredListGroupBy = @GVD_FilteredListGroupBy,
        @IsHidden = @GVD_IsHidden;

    FETCH NEXT FROM GridViewDefinitions_Cursor
    INTO
        @Guid,
        @GVD_RowStatus,
        @GVD_Code,
        @GVD_SourceGridDefinitionID,
        @GVD_DetailPageUri,
        @GVD_SqlQuery,
        @GVD_DefaultSortColumnName,
        @GVD_SecurableCode,
        @GVD_DisplayOrder,
        @GVD_DisplayGroupName,
        @GVD_MetricSqlQuery,
        @GVD_ShowMetric,
        @GVD_IsDetailWindowed,
        @GVD_SourceEntityTypeID,
        @GVD_SourceMetricTypeID,
        @GVD_MetricMin,
        @GVD_MetricMax,
        @GVD_MetricMinorUnit,
        @GVD_MetricMajorUnit,
        @GVD_MetricStartAngle,
        @GVD_MetricEndAngle,
        @GVD_MetricReversed,
        @GVD_MetricRange1Min,
        @GVD_MetricRange1Max,
        @GVD_MetricRange1ColourHex,
        @GVD_MetricRange2Min,
        @GVD_MetricRange2Max,
        @GVD_MetricRange2ColourHex,
        @GVD_IsDefaultSortDescending,
        @GVD_ShowOnMobile,
        @GVD_AllowNew,
        @GVD_AllowExcelExport,
        @GVD_AllowPdfExport,
        @GVD_AllowCsvExport,
        @GVD_SourceLanguageLabelID,
        @GVD_SourceDrawerIconID,
        @GVD_SourceGridViewTypeID,
        @GVD_AllowBulkChange,
        @GVD_TreeListFirstOrderBy,
        @GVD_TreeListSecondOrderBy,
        @GVD_TreeListThirdOrderBy,
        @GVD_TreeListOrderBy,
        @GVD_TreeListGroupBy,
        @GVD_ShowOnDashboard,
        @GVD_FilteredListCreatedOnColumn,
        @GVD_FilteredListRedStatusIndicatorTxt,
        @GVD_FilteredListOrangeStatusIndicatorTxt,
        @GVD_FilteredListGreenStatusIndicatorTxt,
        @GVD_FilteredListGroupBy,
        @GVD_IsHidden;
END;

CLOSE GridViewDefinitions_Cursor;
DEALLOCATE GridViewDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   9. SUserInterface.GridViewColumnDefinitions
   ========================================================= */

DECLARE
    @GVCD_RowStatus TINYINT,
    @GVCD_Name NVARCHAR(250),
    @GVCD_SourceGridViewDefinitionID BIGINT,
    @GVCD_ColumnOrder INT,
    @GVCD_IsPrimaryKey BIT,
    @GVCD_IsHidden BIT,
    @GVCD_IsFiltered BIT,
    @GVCD_IsCombo BIT,
    @GVCD_DisplayFormat NVARCHAR(50),
    @GVCD_Width NVARCHAR(10),
    @GVCD_SourceLanguageLabelID BIGINT,
    @GVCD_TopHeaderCategory NVARCHAR(50),
    @GVCD_TopHeaderCategoryOrder INT,
    @GVCD_SourceRowId BIGINT,
    @GVCD_GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridViewColumnDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionId'))),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.ColumnOrder')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsPrimaryKey')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsFiltered')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCombo')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayFormat'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Width'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategory'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategoryOrder')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewColumnDefinitions_Cursor;

FETCH NEXT FROM GridViewColumnDefinitions_Cursor
INTO
    @Guid,
    @GVCD_RowStatus,
    @GVCD_Name,
    @GVCD_SourceGridViewDefinitionID,
    @GVCD_ColumnOrder,
    @GVCD_IsPrimaryKey,
    @GVCD_IsHidden,
    @GVCD_IsFiltered,
    @GVCD_IsCombo,
    @GVCD_DisplayFormat,
    @GVCD_Width,
    @GVCD_SourceLanguageLabelID,
    @GVCD_TopHeaderCategory,
    @GVCD_TopHeaderCategoryOrder,
    @GVCD_SourceRowId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVCD_GridViewDefinitionGuid = NULL;
    SET @GVCD_LanguageLabelGuid = NULL;
    SELECT
        @GVCD_GridViewDefinitionGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridViewDefinitions'
      AND lookup.SourceRowId = @GVCD_SourceGridViewDefinitionID;

    SELECT
        @GVCD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GVCD_SourceLanguageLabelID;

    DECLARE @ExistingGridViewColumnDefinitionGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @ExistingGridViewColumnDefinitionGuid = gvcd.Guid
    FROM SUserInterface.GridViewColumnDefinitions AS gvcd
    INNER JOIN SUserInterface.GridViewDefinitions AS gvd
        ON gvd.ID = gvcd.GridViewDefinitionID
       AND gvd.RowStatus NOT IN (0,254)
    WHERE gvd.Guid = @GVCD_GridViewDefinitionGuid
      AND gvcd.RowStatus NOT IN (0,254)
      AND gvcd.Guid <> @Guid
      AND
      (
          (
              ISNULL(@GVCD_IsPrimaryKey, 0) = 1
              AND gvcd.IsPrimaryKey = 1
          )
          OR
          (
              ISNULL(@GVCD_IsPrimaryKey, 0) = 0
              AND gvcd.Name = @GVCD_Name
          )
      )
    ORDER BY
        CASE WHEN ISNULL(@GVCD_IsPrimaryKey, 0) = 1 AND gvcd.IsPrimaryKey = 1 THEN 0 ELSE 1 END,
        gvcd.ID;

    DECLARE @GridViewColumnDefinitionGuid UNIQUEIDENTIFIER = ISNULL(@ExistingGridViewColumnDefinitionGuid, @Guid);

    IF @ExistingGridViewColumnDefinitionGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingGridViewColumnDefinitionGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'GridViewColumnDefinitions'
          AND lookup.SourceRowId = @GVCD_SourceRowId;
    END;

    EXEC SUserInterface.GridViewColumnDefinitionUpsert
        @Name = @GVCD_Name,
        @RowStatus = @GVCD_RowStatus,
        @GridViewDefinitionGuid = @GVCD_GridViewDefinitionGuid,
        @ColumnOrder = @GVCD_ColumnOrder,
        @IsPrimaryKey = @GVCD_IsPrimaryKey,
        @IsHidden = @GVCD_IsHidden,
        @IsFiltered = @GVCD_IsFiltered,
        @IsCombo = @GVCD_IsCombo,
        @DisplayFormat = @GVCD_DisplayFormat,
        @Width = @GVCD_Width,
        @LanguageLabelGuid = @GVCD_LanguageLabelGuid,
        @Guid = @GridViewColumnDefinitionGuid OUTPUT,
        @TopHeaderCategory = @GVCD_TopHeaderCategory,
        @TopHeaderCategoryOrder = @GVCD_TopHeaderCategoryOrder;

    FETCH NEXT FROM GridViewColumnDefinitions_Cursor
    INTO
        @Guid,
        @GVCD_RowStatus,
        @GVCD_Name,
        @GVCD_SourceGridViewDefinitionID,
        @GVCD_ColumnOrder,
        @GVCD_IsPrimaryKey,
        @GVCD_IsHidden,
        @GVCD_IsFiltered,
        @GVCD_IsCombo,
        @GVCD_DisplayFormat,
        @GVCD_Width,
        @GVCD_SourceLanguageLabelID,
        @GVCD_TopHeaderCategory,
        @GVCD_TopHeaderCategoryOrder,
        @GVCD_SourceRowId;
END;

CLOSE GridViewColumnDefinitions_Cursor;
DEALLOCATE GridViewColumnDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewColumnDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view column definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   11. Labels
   ========================================================= */

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyLabels',
    @StepStatus = N'Succeeded',
    @Message = N'Labels are applied through SCore.LanguageLabels and SCore.LanguageLabelTranslations handlers.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations"]}';

UPDATE SMigration.Metadata_Run
SET
    RunStatus = N'AppliedUiMetadata',
    AppliedOnUtc = SYSUTCDATETIME()
WHERE Guid = @RunGuid
  AND RowStatus NOT IN (0,254);

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyMetadataComplete',
    @StepStatus = N'Succeeded',
    @Message = N'Core and UI metadata apply handlers completed.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations","SCore.EntityDataTypes","SUserInterface.Icons","SCore.EntityTypes","SCore.EntityHobts","SUserInterface.DropDownListDefinitions","SCore.EntityPropertyGroups","SCore.EntityQueries","SCore.EntityProperties","SCore.EntityQueryParameters","SUserInterface.GridDefinitions","SUserInterface.GridViewDefinitions","SUserInterface.GridViewColumnDefinitions"]}';

COMMIT TRANSACTION;
END;

GOSET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_Upsert]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRunSelection_Upsert]
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

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataRunSelection_Clear]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataRunSelection_Clear]
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

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SMigration].[MetadataApply_Run]')
GO

CREATE OR ALTER PROCEDURE [SMigration].[MetadataApply_Run]
(
    @RunGuid UNIQUEIDENTIFIER,
    @ForceApply BIT = 0,
    @ApplySelectedOnly BIT = 0
)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    DECLARE
        @RunStatus NVARCHAR(30),
        @TargetEnvironment NVARCHAR(20),
        @SourceDatabaseName SYSNAME,
        @FailCount INT = 0,
        @ZeroGuid UNIQUEIDENTIFIER = '00000000-0000-0000-0000-000000000000';

    SELECT
        @RunStatus = r.RunStatus,
        @TargetEnvironment = r.TargetEnvironment,
        @SourceDatabaseName = r.SourceDatabaseName
    FROM SMigration.Metadata_Run AS r
    WHERE r.Guid = @RunGuid
      AND r.RowStatus NOT IN (0,254);

    IF @RunStatus IS NULL
        THROW 52000, 'Metadata run was not found or is inactive.', 1;

    IF @RunStatus NOT IN
    (
        N'Validated',
        N'PartiallyApplied',
        N'AppliedCoreMetadata',
        N'AppliedUiMetadata'
    )
        THROW 52001, 'Metadata run must be Validated, PartiallyApplied, AppliedCoreMetadata or AppliedUiMetadata before apply.', 1;

    SELECT
        @FailCount = COUNT(1)
    FROM SMigration.Metadata_ValidationIssues AS vi
    INNER JOIN SMigration.Metadata_Run AS runScope
        ON runScope.Guid = vi.RunGuid
       AND runScope.RowStatus NOT IN (0,254)
    WHERE vi.RunGuid = @RunGuid
      AND vi.RowStatus NOT IN (0,254)
      AND vi.Severity = N'Fail'
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored
          WHERE ignored.DatabaseName = runScope.TargetDatabaseName
            AND ignored.RegistryGuid = vi.RegistryGuid
            AND ignored.SourceRowGuid = vi.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      );

    IF ISNULL(@FailCount, 0) > 0
        THROW 52002, 'Metadata run has validation failures and cannot be applied.', 1;

    IF @TargetEnvironment = N'LIVE' AND ISNULL(@ForceApply, 0) = 0
        THROW 52003, 'LIVE metadata apply requires @ForceApply = 1.', 1;

    BEGIN TRANSACTION;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyStart',
        @StepStatus = N'Started',
        @Message = N'Metadata apply started.',
        @DetailsJson = N'{}';

    
    IF OBJECT_ID(N'tempdb..#MetadataSourceGuidLookup') IS NOT NULL
        DROP TABLE #MetadataSourceGuidLookup;

    CREATE TABLE #MetadataSourceGuidLookup
    (
        SchemaName SYSNAME NOT NULL,
        TableName SYSNAME NOT NULL,
        SourceRowId BIGINT NOT NULL,
        SourceRowGuid UNIQUEIDENTIFIER NOT NULL,
        CONSTRAINT PK_MetadataSourceGuidLookup PRIMARY KEY CLUSTERED
        (
            SchemaName,
            TableName,
            SourceRowId
        )
    );

    INSERT INTO #MetadataSourceGuidLookup
    (
        SchemaName,
        TableName,
        SourceRowId,
        SourceRowGuid
    )
    SELECT
        tr.SchemaName,
        tr.TableName,
        sr.SourceRowId,
        sr.SourceRowGuid
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.SourceRowId IS NOT NULL
      AND sr.SourceRowGuid IS NOT NULL;

    IF OBJECT_ID(N'tempdb..#MetadataRowsToApply') IS NOT NULL
        DROP TABLE #MetadataRowsToApply;

    CREATE TABLE #MetadataRowsToApply
    (
        StagedRowId BIGINT NOT NULL,
        CONSTRAINT PK_MetadataRowsToApply PRIMARY KEY CLUSTERED (StagedRowId)
    );

    INSERT INTO #MetadataRowsToApply
    (
        StagedRowId
    )
    SELECT
        sr.ID
    FROM SMigration.Metadata_StagedRows AS sr
    INNER JOIN SMigration.Metadata_Run AS runScope
        ON runScope.Guid = sr.RunGuid
       AND runScope.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND NOT EXISTS
      (
          SELECT 1
          FROM SMigration.Metadata_IgnoredRecords AS ignored
          WHERE ignored.DatabaseName = runScope.TargetDatabaseName
            AND ignored.RegistryGuid = sr.RegistryGuid
            AND ignored.SourceRowGuid = sr.SourceRowGuid
            AND ignored.RowStatus NOT IN (0,254)
      )
      AND
      (
          ISNULL(@ApplySelectedOnly, 0) = 0
          OR EXISTS
          (
              SELECT 1
              FROM SMigration.Metadata_RunSelections AS sel
              WHERE sel.RunGuid = sr.RunGuid
                AND sel.RegistryGuid = sr.RegistryGuid
                AND sel.SourceRowGuid = sr.SourceRowGuid
                AND sel.RowStatus NOT IN (0,254)
          )
      );

    IF ISNULL(@ApplySelectedOnly, 0) = 1
       AND NOT EXISTS (SELECT 1 FROM #MetadataRowsToApply)
        THROW 52004, 'Apply selected requires at least one selected Insert or Update metadata row.', 1;

    DECLARE @ApplySelectionDetailsJson NVARCHAR(MAX);

    SELECT
        @ApplySelectionDetailsJson =
        (
            SELECT
                ISNULL(@ApplySelectedOnly, 0) AS applySelectedOnly,
                COUNT_BIG(1) AS rowCount
            FROM #MetadataRowsToApply
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
        );

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplySelectionScope',
        @StepStatus = N'Succeeded',
        @Message = CASE WHEN ISNULL(@ApplySelectedOnly, 0) = 1 THEN N'Metadata apply scoped to selected rows.' ELSE N'Metadata apply scoped to all valid rows.' END,
        @DetailsJson = @ApplySelectionDetailsJson;
/* =========================================================
       1. SCore.LanguageLabels
       ========================================================= */
    DECLARE
        @Guid UNIQUEIDENTIFIER,
        @Name NVARCHAR(500);

    DECLARE LanguageLabels_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name')
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'LanguageLabels'
        ORDER BY sr.SourceRowId;

    OPEN LanguageLabels_Cursor;

    FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        DECLARE @LanguageLabelGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelUpsert
            @Name = @Name,
            @Guid = @LanguageLabelGuid OUTPUT;

        FETCH NEXT FROM LanguageLabels_Cursor INTO @Guid, @Name;
    END;

    CLOSE LanguageLabels_Cursor;
    DEALLOCATE LanguageLabels_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabels',
        @StepStatus = N'Succeeded',
        @Message = N'Language labels applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       2. SCore.LanguageLabelTranslations
       ========================================================= */
    DECLARE
        @Text NVARCHAR(500),
        @TextPlural NVARCHAR(500),
        @HelpText NVARCHAR(MAX),
        @LanguageLabelGuidRef UNIQUEIDENTIFIER,
        @LanguageGuidRef UNIQUEIDENTIFIER,
        @SourceLanguageLabelId BIGINT,
        @SourceLanguageId BIGINT,
        @Sql NVARCHAR(MAX);

    IF OBJECT_ID(N'tempdb..#LanguageLabelTranslationsToApply') IS NOT NULL
        DROP TABLE #LanguageLabelTranslationsToApply;

    CREATE TABLE #LanguageLabelTranslationsToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        Text NVARCHAR(500) NULL,
        TextPlural NVARCHAR(500) NULL,
        HelpText NVARCHAR(MAX) NULL,
        SourceLanguageLabelId BIGINT NULL,
        SourceLanguageId BIGINT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #LanguageLabelTranslationsToApply
    (
        Guid,
        Text,
        TextPlural,
        HelpText,
        SourceLanguageLabelId,
        SourceLanguageId,
        SourceRowId
    )
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Text'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TextPlural'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.HelpText'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageId'))),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'LanguageLabelTranslations';

    DECLARE LanguageLabelTranslations_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            Text,
            TextPlural,
            HelpText,
            SourceLanguageLabelId,
            SourceLanguageId
        FROM #LanguageLabelTranslationsToApply
        ORDER BY SourceRowId;

    OPEN LanguageLabelTranslations_Cursor;

    FETCH NEXT FROM LanguageLabelTranslations_Cursor
    INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT
            @LanguageLabelGuidRef = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'LanguageLabels'
          AND lookup.SourceRowId = @SourceLanguageLabelId;

        SELECT
            @LanguageGuidRef = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'Languages'
          AND lookup.SourceRowId = @SourceLanguageId;

        DECLARE @LanguageLabelTranslationGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.LanguageLabelTranslationUpsert
            @Text = @Text,
            @TextPlural = @TextPlural,
            @HelpText = @HelpText,
            @LanguageLabelGuid = @LanguageLabelGuidRef,
            @LanguageGuid = @LanguageGuidRef,
            @Guid = @LanguageLabelTranslationGuid OUTPUT;

        FETCH NEXT FROM LanguageLabelTranslations_Cursor
        INTO @Guid, @Text, @TextPlural, @HelpText, @SourceLanguageLabelId, @SourceLanguageId;
    END;

    CLOSE LanguageLabelTranslations_Cursor;
    DEALLOCATE LanguageLabelTranslations_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyLanguageLabelTranslations',
        @StepStatus = N'Succeeded',
        @Message = N'Language label translations applied.',
        @DetailsJson = N'{}';


    
/* =========================================================
       3. SCore.EntityDataTypes
       Required reference metadata for EntityProperties and EntityQueryParameters.
       No dedicated EntityDataTypeUpsert exists in the current schema, so this
       handler uses SCore.UpsertDataObject and explicit idempotent DML.
       ========================================================= */
    DECLARE
        @EDT_RowStatus TINYINT,
        @EDT_Name NVARCHAR(250),
        @EDT_QuoteValue BIT,
        @EDT_IsInsert BIT;

    DECLARE EntityDataTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.QuoteValue'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityDataTypes'
        ORDER BY sr.SourceRowId;

    OPEN EntityDataTypes_Cursor;

    FETCH NEXT FROM EntityDataTypes_Cursor
    INTO
        @Guid,
        @EDT_RowStatus,
        @EDT_Name,
        @EDT_QuoteValue;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EDT_IsInsert = 0;

        EXEC SCore.UpsertDataObject
            @Guid = @Guid,
            @SchemeName = N'SCore',
            @ObjectName = N'EntityDataTypes',
            @IsInsert = @EDT_IsInsert OUTPUT;

        IF @EDT_IsInsert = 1
        BEGIN
            INSERT INTO SCore.EntityDataTypes
            (
                Guid,
                RowStatus,
                Name,
                QuoteValue
            )
            VALUES
            (
                @Guid,
                ISNULL(NULLIF(@EDT_RowStatus, 0), 1),
                ISNULL(@EDT_Name, N''),
                ISNULL(@EDT_QuoteValue, 0)
            );
        END;
        ELSE
        BEGIN
            UPDATE SCore.EntityDataTypes
            SET
                RowStatus = ISNULL(NULLIF(@EDT_RowStatus, 0), RowStatus),
                Name = ISNULL(@EDT_Name, N''),
                QuoteValue = ISNULL(@EDT_QuoteValue, 0)
            WHERE Guid = @Guid;
        END;

        FETCH NEXT FROM EntityDataTypes_Cursor
        INTO
            @Guid,
            @EDT_RowStatus,
            @EDT_Name,
            @EDT_QuoteValue;
    END;

    CLOSE EntityDataTypes_Cursor;
    DEALLOCATE EntityDataTypes_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityDataTypes',
        @StepStatus = N'Succeeded',
        @Message = N'Entity data types applied.',
        @DetailsJson = N'{}';

    /* =========================================================
       4. SUserInterface.Icons
       Required reference metadata for EntityTypes and GridViewDefinitions.
       No dedicated IconUpsert exists in the current schema, so this
       handler uses SCore.UpsertDataObject and explicit idempotent DML.
       Natural key fallback is Name to avoid duplicate icon CSS classes.
       ========================================================= */
    DECLARE
        @ICON_RowStatus TINYINT,
        @ICON_Name NVARCHAR(50),
        @ICON_SourceRowId BIGINT,
        @ICON_IsInsert BIT,
        @ICON_ExistingGuid UNIQUEIDENTIFIER,
        @ICON_GuidToApply UNIQUEIDENTIFIER;

    DECLARE Icons_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            sr.SourceRowId
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SUserInterface'
          AND tr.TableName = N'Icons'
        ORDER BY sr.SourceRowId;

    OPEN Icons_Cursor;

    FETCH NEXT FROM Icons_Cursor
    INTO
        @Guid,
        @ICON_RowStatus,
        @ICON_Name,
        @ICON_SourceRowId;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ICON_ExistingGuid = NULL;
        SET @ICON_GuidToApply = @Guid;
        SET @ICON_IsInsert = 0;

        SELECT TOP (1)
            @ICON_ExistingGuid = i.Guid
        FROM SUserInterface.Icons AS i
        WHERE i.Name = ISNULL(@ICON_Name, N'')
          AND i.RowStatus NOT IN (0,254)
          AND i.Guid <> @Guid
        ORDER BY i.ID;

        IF @ICON_ExistingGuid IS NOT NULL
        BEGIN
            SET @ICON_GuidToApply = @ICON_ExistingGuid;

            UPDATE lookup
            SET SourceRowGuid = @ICON_ExistingGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SUserInterface'
              AND lookup.TableName = N'Icons'
              AND lookup.SourceRowId = @ICON_SourceRowId;
        END;

        EXEC SCore.UpsertDataObject
            @Guid = @ICON_GuidToApply,
            @SchemeName = N'SUserInterface',
            @ObjectName = N'Icons',
            @IsInsert = @ICON_IsInsert OUTPUT;

        IF @ICON_IsInsert = 1
        BEGIN
            INSERT INTO SUserInterface.Icons
            (
                Guid,
                RowStatus,
                Name
            )
            VALUES
            (
                @ICON_GuidToApply,
                ISNULL(NULLIF(@ICON_RowStatus, 0), 1),
                ISNULL(@ICON_Name, N'')
            );
        END;
        ELSE
        BEGIN
            UPDATE SUserInterface.Icons
            SET
                RowStatus = ISNULL(NULLIF(@ICON_RowStatus, 0), RowStatus),
                Name = ISNULL(@ICON_Name, N'')
            WHERE Guid = @ICON_GuidToApply;
        END;

        FETCH NEXT FROM Icons_Cursor
        INTO
            @Guid,
            @ICON_RowStatus,
            @ICON_Name,
            @ICON_SourceRowId;
    END;

    CLOSE Icons_Cursor;
    DEALLOCATE Icons_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyIcons',
        @StepStatus = N'Succeeded',
        @Message = N'Icons applied.',
        @DetailsJson = N'{}';


/* =========================================================
       3. SCore.EntityTypes
       Required reference metadata for EntityQueries/GridViews/DropDownLists.
       Applies staged EntityTypes before dependent metadata.
       ========================================================= */
    DECLARE
        @ET_RowStatus TINYINT,
        @ET_IsReadOnlyOffline BIT,
        @ET_IsRequiredSystemData BIT,
        @ET_HasDocuments BIT,
        @ET_SourceLanguageLabelID BIGINT,
        @ET_DoNotTrackChanges BIT,
        @ET_SourceIconID BIGINT,
        @ET_IsRootEntity BIT,
        @ET_DetailPageUrl NVARCHAR(250),
        @ET_IsMetaData BIT,
        @ET_IsDeletable BIT,
        @ET_LanguageLabelGuid UNIQUEIDENTIFIER,
        @ET_IconGuid UNIQUEIDENTIFIER;

    DECLARE EntityTypes_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsRequiredSystemData')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.HasDocuments')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.IconID'), JSON_VALUE(sr.SourcePayloadJson, N'$.IconId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsRootEntity')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMetaData')),
            ISNULL(TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDeletable')), 1)
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityTypes'
        ORDER BY sr.SourceRowId;

    OPEN EntityTypes_Cursor;

    FETCH NEXT FROM EntityTypes_Cursor
    INTO
        @Guid,
        @ET_RowStatus,
        @Name,
        @ET_IsReadOnlyOffline,
        @ET_IsRequiredSystemData,
        @ET_HasDocuments,
        @ET_SourceLanguageLabelID,
        @ET_DoNotTrackChanges,
        @ET_SourceIconID,
        @ET_IsRootEntity,
        @ET_DetailPageUrl,
            @ET_IsMetaData,
            @ET_IsDeletable;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @ET_LanguageLabelGuid = NULL;
        SET @ET_IconGuid = NULL;

        SELECT
            @ET_LanguageLabelGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'LanguageLabels'
          AND lookup.SourceRowId = @ET_SourceLanguageLabelID;

        SELECT
            @ET_IconGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'Icons'
          AND lookup.SourceRowId = @ET_SourceIconID;

        DECLARE @EntityTypeGuidToApply UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityTypeUpsert
            @Name = @Name,
            @RowStatus = @ET_RowStatus,
            @IsReadOnlyOffline = @ET_IsReadOnlyOffline,
            @IsRequiredSystemData = @ET_IsRequiredSystemData,
            @HasDocuments = @ET_HasDocuments,
            @LanguageLabelGuid = @ET_LanguageLabelGuid,
            @DoNotTrackChanges = @ET_DoNotTrackChanges,
            @IconGuid = @ET_IconGuid,
            @IsRootEntity = @ET_IsRootEntity,
            @DetailPageUrl = @ET_DetailPageUrl,
            @IsMetaData = @ET_IsMetaData,
            @IsDeletable = @ET_IsDeletable,
            @Guid = @EntityTypeGuidToApply OUTPUT;

        FETCH NEXT FROM EntityTypes_Cursor
        INTO
            @Guid,
            @ET_RowStatus,
            @Name,
            @ET_IsReadOnlyOffline,
            @ET_IsRequiredSystemData,
            @ET_HasDocuments,
            @ET_SourceLanguageLabelID,
            @ET_DoNotTrackChanges,
            @ET_SourceIconID,
            @ET_IsRootEntity,
            @ET_DetailPageUrl,
            @ET_IsMetaData,
            @ET_IsDeletable;
    END;

    CLOSE EntityTypes_Cursor;
    DEALLOCATE EntityTypes_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityTypes',
        @StepStatus = N'Succeeded',
        @Message = N'Entity types applied.',
        @DetailsJson = N'{}';


    /* =========================================================
       4. SCore.EntityHobts
       Required reference metadata for EntityQueries and EntityProperties.
       Applies staged HoBTs after EntityTypes and before dependent metadata.
       ========================================================= */
    DECLARE
        @EH_RowStatus TINYINT,
        @EH_SchemaName NVARCHAR(250),
        @EH_ObjectName NVARCHAR(250),
        @EH_SourceEntityTypeID BIGINT,
        @EH_ObjectType NVARCHAR(1),
        @EH_IsMainHoBT BIT,
        @EH_IsReadOnlyOffline BIT,
        @EH_EntityTypeGuid UNIQUEIDENTIFIER;

    DECLARE EntityHobts_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectType'), N'T'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMainHoBT')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnlyOffline'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityHobts'
        ORDER BY sr.SourceRowId;

    OPEN EntityHobts_Cursor;

    FETCH NEXT FROM EntityHobts_Cursor
    INTO
        @Guid,
        @EH_RowStatus,
        @EH_SchemaName,
        @EH_ObjectName,
        @EH_SourceEntityTypeID,
        @EH_ObjectType,
        @EH_IsMainHoBT,
        @EH_IsReadOnlyOffline;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EH_EntityTypeGuid = NULL;

        SELECT
            @EH_EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @EH_SourceEntityTypeID;

        IF @EH_EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingHoBTEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityHobts apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EH_SourceEntityTypeID), N'<NULL>'), N' for HoBT ', COALESCE(@EH_SchemaName + N'.' + @EH_ObjectName, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityHobts.');
            THROW 52021, @MissingHoBTEntityTypeMessage, 1;
        END;

        DECLARE @EntityHoBTGuidToApply UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityHoBTUpsert
            @SchemaName = @EH_SchemaName,
            @ObjectName = @EH_ObjectName,
            @ObjectType = @EH_ObjectType,
            @IsMainHoBT = @EH_IsMainHoBT,
            @IsReadOnlyOffline = @EH_IsReadOnlyOffline,
            @EntityTypeGuid = @EH_EntityTypeGuid,
            @Guid = @EntityHoBTGuidToApply OUTPUT;

        FETCH NEXT FROM EntityHobts_Cursor
        INTO
            @Guid,
            @EH_RowStatus,
            @EH_SchemaName,
            @EH_ObjectName,
            @EH_SourceEntityTypeID,
            @EH_ObjectType,
            @EH_IsMainHoBT,
            @EH_IsReadOnlyOffline;
    END;

    CLOSE EntityHobts_Cursor;
    DEALLOCATE EntityHobts_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityHobts',
        @StepStatus = N'Succeeded',
        @Message = N'Entity HoBTs applied.',
        @DetailsJson = N'{}';

    /* =========================================================
   10. SUserInterface.DropDownListDefinitions
   ========================================================= */

DECLARE
    @DDL_Code NVARCHAR(20),
    @DDL_NameColumn NVARCHAR(254),
    @DDL_ValueColumn NVARCHAR(254),
    @DDL_SqlQuery NVARCHAR(MAX),
    @DDL_DefaultSortColumnName NVARCHAR(254),
    @DDL_IsDefaultColumn BIT,
    @DDL_IsDetailWindowed BIT,
    @DDL_DetailPageURI NVARCHAR(250),
    @DDL_SourceEntityTypeID BIGINT,
    @DDL_InformationPageURI NVARCHAR(250),
    @DDL_GroupColumn NVARCHAR(254),
    @DDL_ColourHexColumn NVARCHAR(7),
    @DDL_ExternalSearchPageUrl NVARCHAR(250),
    @DDL_EntityTypeGuid UNIQUEIDENTIFIER;

DECLARE DropDownListDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.NameColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ValueColumn'),
        ddlJsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultColumn')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUrl'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.InformationPageUrl'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.GroupColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ColourHexColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ExternalSearchPageUrl')
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery'
    ) AS ddlJsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'DropDownListDefinitions'
    ORDER BY sr.SourceRowId;

OPEN DropDownListDefinitions_Cursor;

FETCH NEXT FROM DropDownListDefinitions_Cursor
INTO
    @Guid,
    @DDL_Code,
    @DDL_NameColumn,
    @DDL_ValueColumn,
    @DDL_SqlQuery,
    @DDL_DefaultSortColumnName,
    @DDL_IsDefaultColumn,
    @DDL_IsDetailWindowed,
    @DDL_DetailPageURI,
    @DDL_SourceEntityTypeID,
    @DDL_InformationPageURI,
    @DDL_GroupColumn,
    @DDL_ColourHexColumn,
    @DDL_ExternalSearchPageUrl;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @DDL_EntityTypeGuid = NULL;
    IF @DDL_SourceEntityTypeID IS NULL OR @DDL_SourceEntityTypeID <= 0
    BEGIN
        SET @DDL_EntityTypeGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @DDL_EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @DDL_SourceEntityTypeID;
    END;

    IF @DDL_EntityTypeGuid IS NULL
    BEGIN
        DECLARE @MissingDDLTargetEntityTypeMessage NVARCHAR(4000) = CONCAT(N'DropDownListDefinitions apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @DDL_SourceEntityTypeID), N'<NULL>'), N' for drop-down list ', COALESCE(@DDL_Code, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SUserInterface.DropDownListDefinitions.');
        THROW 52028, @MissingDDLTargetEntityTypeMessage, 1;
    END;

    DECLARE @DropDownListDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.DropDownListDefinitionUpsert
        @Code = @DDL_Code,
        @NameColumn = @DDL_NameColumn,
        @ValueColumn = @DDL_ValueColumn,
        @SqlQuery = @DDL_SqlQuery,
        @DefaultSortColumnName = @DDL_DefaultSortColumnName,
        @IsDefaultColumn = @DDL_IsDefaultColumn,
        @IsDetailWindowed = @DDL_IsDetailWindowed,
        @DetailPageURI = @DDL_DetailPageURI,
        @EntityTypeGuid = @DDL_EntityTypeGuid,
        @InformationPageURI = @DDL_InformationPageURI,
        @GroupColumn = @DDL_GroupColumn,
        @Guid = @DropDownListDefinitionGuid OUTPUT,
        @ColourHexColumn = @DDL_ColourHexColumn,
        @ExternalSearchPageUrl = @DDL_ExternalSearchPageUrl;

    FETCH NEXT FROM DropDownListDefinitions_Cursor
    INTO
        @Guid,
        @DDL_Code,
        @DDL_NameColumn,
        @DDL_ValueColumn,
        @DDL_SqlQuery,
        @DDL_DefaultSortColumnName,
        @DDL_IsDefaultColumn,
        @DDL_IsDetailWindowed,
        @DDL_DetailPageURI,
        @DDL_SourceEntityTypeID,
        @DDL_InformationPageURI,
        @DDL_GroupColumn,
        @DDL_ColourHexColumn,
        @DDL_ExternalSearchPageUrl;
END;

CLOSE DropDownListDefinitions_Cursor;
DEALLOCATE DropDownListDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyDropDownListDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Drop-down list definitions applied.',
    @DetailsJson = N'{}';


/* =========================================================
       8. SCore.EntityPropertyGroups
       Required reference metadata for EntityProperties.
       ========================================================= */
    DECLARE
        @EPG_RowStatus TINYINT,
        @EPG_Name NVARCHAR(250),
        @EPG_IsHidden BIT,
        @EPG_SortOrder INT,
        @EPG_SourceLanguageLabelID BIGINT,
        @EPG_SourceEntityTypeID BIGINT,
        @EPG_SourcePropertyGroupLayoutID BIGINT,
        @EPG_ShowOnMobile BIT,
        @EPG_IsCollapsable BIT,
        @EPG_IsDefaultCollapsed BIT,
        @EPG_IsDefaultCollapsed_Mobile BIT,
        @EPG_LanguageLabelGuid UNIQUEIDENTIFIER,
        @EPG_EntityTypeGuid UNIQUEIDENTIFIER,
        @EPG_PropertyGroupLayoutGuid UNIQUEIDENTIFIER;

    DECLARE EntityPropertyGroups_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            sr.SourceRowGuid,
            TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
            JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
            TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
            TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.PropertyGroupLayoutID'), JSON_VALUE(sr.SourcePayloadJson, N'$.PropertyGroupLayoutId'))),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCollapsable')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed')),
            TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCollapsed_Mobile'))
        FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
        INNER JOIN SMigration.Metadata_TableRegistry AS tr
            ON tr.Guid = sr.RegistryGuid
           AND tr.RowStatus NOT IN (0,254)
        WHERE sr.RunGuid = @RunGuid
          AND sr.RowStatus NOT IN (0,254)
          AND sr.DifferenceType IN (N'Insert', N'Update')
          AND tr.SchemaName = N'SCore'
          AND tr.TableName = N'EntityPropertyGroups'
        ORDER BY sr.SourceRowId;

    OPEN EntityPropertyGroups_Cursor;

    FETCH NEXT FROM EntityPropertyGroups_Cursor
    INTO
        @Guid,
        @EPG_RowStatus,
        @EPG_Name,
        @EPG_IsHidden,
        @EPG_SortOrder,
        @EPG_SourceLanguageLabelID,
        @EPG_SourceEntityTypeID,
        @EPG_SourcePropertyGroupLayoutID,
        @EPG_ShowOnMobile,
        @EPG_IsCollapsable,
        @EPG_IsDefaultCollapsed,
        @EPG_IsDefaultCollapsed_Mobile;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EPG_LanguageLabelGuid = NULL;
        SET @EPG_EntityTypeGuid = NULL;
        SET @EPG_PropertyGroupLayoutGuid = NULL;

        IF @EPG_SourceLanguageLabelID IS NULL OR @EPG_SourceLanguageLabelID <= 0
        BEGIN
            SET @EPG_LanguageLabelGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_LanguageLabelGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SCore'
              AND lookup.TableName = N'LanguageLabels'
              AND lookup.SourceRowId = @EPG_SourceLanguageLabelID;
        END;

        IF @EPG_SourceEntityTypeID IS NULL OR @EPG_SourceEntityTypeID <= 0
        BEGIN
            SET @EPG_EntityTypeGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_EntityTypeGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SCore'
              AND lookup.TableName = N'EntityTypes'
              AND lookup.SourceRowId = @EPG_SourceEntityTypeID;
        END;

        IF @EPG_SourcePropertyGroupLayoutID IS NULL OR @EPG_SourcePropertyGroupLayoutID <= 0
        BEGIN
            SET @EPG_PropertyGroupLayoutGuid = @ZeroGuid;
        END;
        ELSE
        BEGIN
            SELECT
                @EPG_PropertyGroupLayoutGuid = lookup.SourceRowGuid
            FROM #MetadataSourceGuidLookup AS lookup
            WHERE lookup.SchemaName = N'SUserInterface'
              AND lookup.TableName = N'PropertyGroupLayouts'
              AND lookup.SourceRowId = @EPG_SourcePropertyGroupLayoutID;
        END;

        IF @EPG_LanguageLabelGuid IS NULL
        BEGIN
            DECLARE @MissingEPGLanguageLabelMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve LanguageLabel source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourceLanguageLabelID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.LanguageLabels is staged/applied before SCore.EntityPropertyGroups.');
            THROW 52025, @MissingEPGLanguageLabelMessage, 1;
        END;

        IF @EPG_EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingEPGEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourceEntityTypeID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityPropertyGroups.');
            THROW 52026, @MissingEPGEntityTypeMessage, 1;
        END;

        IF @EPG_PropertyGroupLayoutGuid IS NULL
        BEGIN
            DECLARE @MissingEPGLayoutMessage NVARCHAR(4000) = CONCAT(N'EntityPropertyGroups apply could not resolve PropertyGroupLayout source ID ', COALESCE(CONVERT(NVARCHAR(30), @EPG_SourcePropertyGroupLayoutID), N'<NULL>'), N' for group ', COALESCE(@EPG_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SUserInterface.PropertyGroupLayouts is included as reference metadata if this is not the zero/default layout.');
            THROW 52027, @MissingEPGLayoutMessage, 1;
        END;

        DECLARE @EntityPropertyGroupGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityPropertyGroupUpsert
            @Name = @EPG_Name,
            @RowStatus = @EPG_RowStatus,
            @IsHidden = @EPG_IsHidden,
            @SortOrder = @EPG_SortOrder,
            @LanguageLabelGuid = @EPG_LanguageLabelGuid,
            @EntityTypeGuid = @EPG_EntityTypeGuid,
            @PropertyGroupLayoutGuid = @EPG_PropertyGroupLayoutGuid,
            @ShowOnMobile = @EPG_ShowOnMobile,
            @IsCollapsable = @EPG_IsCollapsable,
            @IsDefaultCollapsed = @EPG_IsDefaultCollapsed,
            @IsDefaultCollapsed_Mobile = @EPG_IsDefaultCollapsed_Mobile,
            @Guid = @EntityPropertyGroupGuid OUTPUT;

        FETCH NEXT FROM EntityPropertyGroups_Cursor
        INTO
            @Guid,
            @EPG_RowStatus,
            @EPG_Name,
            @EPG_IsHidden,
            @EPG_SortOrder,
            @EPG_SourceLanguageLabelID,
            @EPG_SourceEntityTypeID,
            @EPG_SourcePropertyGroupLayoutID,
            @EPG_ShowOnMobile,
            @EPG_IsCollapsable,
            @EPG_IsDefaultCollapsed,
            @EPG_IsDefaultCollapsed_Mobile;
    END;

    CLOSE EntityPropertyGroups_Cursor;
    DEALLOCATE EntityPropertyGroups_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityPropertyGroups',
        @StepStatus = N'Succeeded',
        @Message = N'Entity property groups applied.',
        @DetailsJson = N'{}';

/* =========================================================
       5. SCore.EntityQueries
       ========================================================= */
    DECLARE
        @Statement NVARCHAR(MAX),
        @EntityTypeGuid UNIQUEIDENTIFIER,
        @EntityHoBTGuid UNIQUEIDENTIFIER,
        @IsDefaultCreate BIT,
        @IsDefaultRead BIT,
        @IsDefaultUpdate BIT,
        @IsDefaultDelete BIT,
        @IsScalarExecute BIT,
        @IsDefaultValidation BIT,
        @IsDefaultDataPills BIT,
        @IsMergeDocumentQuery BIT,
        @IsProgressData BIT,
        @SchemaName NVARCHAR(255),
        @ObjectName NVARCHAR(255),
        @IsManualStatement BIT,
        @RowStatus TINYINT,
        @SourceEntityTypeId BIGINT,
        @SourceEntityHoBTId BIGINT;

    IF OBJECT_ID(N'tempdb..#EntityQueriesToApply') IS NOT NULL
        DROP TABLE #EntityQueriesToApply;

    CREATE TABLE #EntityQueriesToApply
    (
        Guid UNIQUEIDENTIFIER NOT NULL,
        RowStatus TINYINT NULL,
        Name NVARCHAR(500) NULL,
        Statement NVARCHAR(MAX) NULL,
        SourceEntityTypeId BIGINT NULL,
        SourceEntityHoBTId BIGINT NULL,
        IsDefaultCreate BIT NULL,
        IsDefaultRead BIT NULL,
        IsDefaultUpdate BIT NULL,
        IsDefaultDelete BIT NULL,
        IsScalarExecute BIT NULL,
        IsDefaultValidation BIT NULL,
        IsDefaultDataPills BIT NULL,
        IsMergeDocumentQuery BIT NULL,
        IsProgressData BIT NULL,
        SchemaName NVARCHAR(255) NULL,
        ObjectName NVARCHAR(255) NULL,
        IsManualStatement BIT NULL,
        SourceRowId BIGINT NULL
    );

    INSERT INTO #EntityQueriesToApply
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        jsonPayload.Statement,
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTId'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtId'))),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultCreate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultRead')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultUpdate')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDelete')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsScalarExecute')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultValidation')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultDataPills')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsMergeDocumentQuery')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsProgressData')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SchemaName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.ObjectName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsManualStatement')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    OUTER APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        Statement NVARCHAR(MAX) N'$.Statement'
    ) AS jsonPayload
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueries';

    DECLARE EntityQueries_Cursor CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            Guid,
            RowStatus,
            Name,
            Statement,
            SourceEntityTypeId,
            SourceEntityHoBTId,
            IsDefaultCreate,
            IsDefaultRead,
            IsDefaultUpdate,
            IsDefaultDelete,
            IsScalarExecute,
            IsDefaultValidation,
            IsDefaultDataPills,
            IsMergeDocumentQuery,
            IsProgressData,
            SchemaName,
            ObjectName,
            IsManualStatement
        FROM #EntityQueriesToApply
        ORDER BY SourceRowId;

    OPEN EntityQueries_Cursor;

    FETCH NEXT FROM EntityQueries_Cursor
    INTO
        @Guid,
        @RowStatus,
        @Name,
        @Statement,
        @SourceEntityTypeId,
        @SourceEntityHoBTId,
        @IsDefaultCreate,
        @IsDefaultRead,
        @IsDefaultUpdate,
        @IsDefaultDelete,
        @IsScalarExecute,
        @IsDefaultValidation,
        @IsDefaultDataPills,
        @IsMergeDocumentQuery,
        @IsProgressData,
        @SchemaName,
        @ObjectName,
        @IsManualStatement;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @EntityTypeGuid = NULL;
        SET @EntityHoBTGuid = NULL;

        SELECT
            @EntityTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityTypes'
          AND lookup.SourceRowId = @SourceEntityTypeId;

        SELECT
            @EntityHoBTGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityHobts'
          AND lookup.SourceRowId = @SourceEntityHoBTId;

        IF @EntityTypeGuid IS NULL
        BEGIN
            DECLARE @MissingEntityTypeMessage NVARCHAR(4000) = CONCAT(N'EntityQueries apply could not resolve EntityType source ID ', COALESCE(CONVERT(NVARCHAR(30), @SourceEntityTypeId), N'<NULL>'), N' for query ', COALESCE(@Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityTypes is staged/applied before SCore.EntityQueries.');
            THROW 52020, @MissingEntityTypeMessage, 1;
        END;

        DECLARE @EntityQueryGuid UNIQUEIDENTIFIER = @Guid;

        EXEC SCore.EntityQueryUpsert
            @Name = @Name,
            @RowStatus = @RowStatus,
            @Statement = @Statement,
            @EntityTypeGuid = @EntityTypeGuid,
            @IsDefaultCreate = @IsDefaultCreate,
            @IsDefaultRead = @IsDefaultRead,
            @IsDefaultUpdate = @IsDefaultUpdate,
            @IsDefaultDelete = @IsDefaultDelete,
            @IsScalarExecute = @IsScalarExecute,
            @IsDefaultValidation = @IsDefaultValidation,
            @EntityHoBTGuid = @EntityHoBTGuid,
            @IsDefaultDataPills = @IsDefaultDataPills,
            @IsMergeDocumentQuery = @IsMergeDocumentQuery,
            @IsProgressData = @IsProgressData,
            @SchemaName = @SchemaName,
            @ObjectName = @ObjectName,
            @IsManualStatement = @IsManualStatement,
            @Guid = @EntityQueryGuid OUTPUT;

        FETCH NEXT FROM EntityQueries_Cursor
        INTO
            @Guid,
            @RowStatus,
            @Name,
            @Statement,
            @SourceEntityTypeId,
            @SourceEntityHoBTId,
            @IsDefaultCreate,
            @IsDefaultRead,
            @IsDefaultUpdate,
            @IsDefaultDelete,
            @IsScalarExecute,
            @IsDefaultValidation,
            @IsDefaultDataPills,
            @IsMergeDocumentQuery,
            @IsProgressData,
            @SchemaName,
            @ObjectName,
            @IsManualStatement;
    END;

    CLOSE EntityQueries_Cursor;
    DEALLOCATE EntityQueries_Cursor;

    EXEC SMigration.MetadataExecutionLog_Add
        @RunGuid = @RunGuid,
        @StepName = N'ApplyEntityQueries',
        @StepStatus = N'Succeeded',
        @Message = N'Entity queries applied.',
        @DetailsJson = N'{}';

/* =========================================================
   5. SCore.EntityProperties
   ========================================================= */

DECLARE
    @EP_RowStatus TINYINT,
    @EP_Name NVARCHAR(500),
    @EP_SourceLanguageLabelID BIGINT,
    @EP_SourceEntityHoBTID BIGINT,
    @EP_SourceEntityDataTypeID BIGINT,
    @EP_SourceEntityPropertyGroupID BIGINT,
    @EP_SourceDropDownListDefinitionID BIGINT,
    @EP_SourceRowId BIGINT,
    @EP_LanguageLabelGuid UNIQUEIDENTIFIER,
    @EP_EntityHoBTGuid UNIQUEIDENTIFIER,
    @EP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EP_EntityPropertyGroupGuid UNIQUEIDENTIFIER,
    @EP_DropDownListDefinitionGuid UNIQUEIDENTIFIER,
    @EP_IsReadOnly BIT,
    @EP_IsImmutable BIT,
    @EP_IsUppercase BIT,
    @EP_IsHidden BIT,
    @EP_IsCompulsory BIT,
    @EP_MaxLength INT,
    @EP_Precision INT,
    @EP_Scale INT,
    @EP_DoNotTrackChanges BIT,
    @EP_SortOrder SMALLINT,
    @EP_GroupSortOrder SMALLINT,
    @EP_IsObjectLabel BIT,
    @EP_IsParentRelationship BIT,
    @EP_IsIncludedInformation BIT,
    @EP_IsLatitude BIT,
    @EP_IsLongitude BIT,
    @EP_FixDefaultValue NVARCHAR(100),
    @EP_SqlDefaultValueStatement NVARCHAR(MAX),
    @EP_AllowBulkChange BIT,
    @EP_IsVirtual BIT,
    @EP_ShowOnMobile BIT,
    @EP_IsAlwaysVisibleInGroup BIT,
    @EP_IsAlwaysVisibleInGroup_Mobile BIT;

IF OBJECT_ID(N'tempdb..#EntityPropertiesToApply') IS NOT NULL
    DROP TABLE #EntityPropertiesToApply;

CREATE TABLE #EntityPropertiesToApply
(
    Guid UNIQUEIDENTIFIER NOT NULL,
    RowStatus TINYINT NULL,
    Name NVARCHAR(500) NULL,
    SourceLanguageLabelID BIGINT NULL,
    SourceEntityHoBTID BIGINT NULL,
    SourceEntityDataTypeID BIGINT NULL,
    IsReadOnly BIT NULL,
    IsImmutable BIT NULL,
    IsUppercase BIT NULL,
    IsHidden BIT NULL,
    IsCompulsory BIT NULL,
    MaxLength INT NULL,
    PrecisionValue INT NULL,
    ScaleValue INT NULL,
    DoNotTrackChanges BIT NULL,
    SourceEntityPropertyGroupID BIGINT NULL,
    SortOrder SMALLINT NULL,
    GroupSortOrder SMALLINT NULL,
    IsObjectLabel BIT NULL,
    SourceDropDownListDefinitionID BIGINT NULL,
    IsParentRelationship BIT NULL,
    IsIncludedInformation BIT NULL,
    IsLatitude BIT NULL,
    IsLongitude BIT NULL,
    FixDefaultValue NVARCHAR(100) NULL,
    SqlDefaultValueStatement NVARCHAR(MAX) NULL,
    AllowBulkChange BIT NULL,
    IsVirtual BIT NULL,
    ShowOnMobile BIT NULL,
    IsAlwaysVisibleInGroup BIT NULL,
    IsAlwaysVisibleInGroup_Mobile BIT NULL,
    SourceRowId BIGINT NULL
);

INSERT INTO #EntityPropertiesToApply
SELECT
    sr.SourceRowGuid,
    TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
    JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHoBTId'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityHobtId'))),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeId'))),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReadOnly')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsImmutable')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsUppercase')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCompulsory')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MaxLength')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Precision')),
    TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.Scale')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.DoNotTrackChanges')),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityPropertyGroupId'))),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.SortOrder')),
    TRY_CONVERT(SMALLINT, JSON_VALUE(sr.SourcePayloadJson, N'$.GroupSortOrder')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsObjectLabel')),
    TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.DropDownListDefinitionId'))),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsParentRelationship')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsIncludedInformation')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLatitude')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsLongitude')),
    ISNULL
    (
        COALESCE
        (
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixedDefaultValue'),
            JSON_VALUE(sr.SourcePayloadJson, N'$.FixDefaultValue')
        ),
        N''
    ),
    epjson.SqlDefaultValueStatement,
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsVirtual')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup')),
    TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsAlwaysVisibleInGroup_Mobile')),
    sr.SourceRowId
FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
INNER JOIN SMigration.Metadata_TableRegistry AS tr
    ON tr.Guid = sr.RegistryGuid
   AND tr.RowStatus NOT IN (0,254)
OUTER APPLY OPENJSON(sr.SourcePayloadJson)
WITH
(
    SqlDefaultValueStatement NVARCHAR(MAX) N'$.SqlDefaultValueStatement'
) AS epjson
WHERE sr.RunGuid = @RunGuid
  AND sr.RowStatus NOT IN (0,254)
  AND sr.DifferenceType IN (N'Insert', N'Update')
  AND tr.SchemaName = N'SCore'
  AND tr.TableName = N'EntityProperties';

DECLARE EntityProperties_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        Guid,
        RowStatus,
        Name,
        SourceLanguageLabelID,
        SourceEntityHoBTID,
        SourceEntityDataTypeID,
        IsReadOnly,
        IsImmutable,
        IsUppercase,
        IsHidden,
        IsCompulsory,
        MaxLength,
        PrecisionValue,
        ScaleValue,
        DoNotTrackChanges,
        SourceEntityPropertyGroupID,
        SortOrder,
        GroupSortOrder,
        IsObjectLabel,
        SourceDropDownListDefinitionID,
        IsParentRelationship,
        IsIncludedInformation,
        IsLatitude,
        IsLongitude,
        FixDefaultValue,
        SqlDefaultValueStatement,
        AllowBulkChange,
        IsVirtual,
        ShowOnMobile,
        IsAlwaysVisibleInGroup,
        IsAlwaysVisibleInGroup_Mobile,
        SourceRowId
    FROM #EntityPropertiesToApply
    ORDER BY SourceRowId;

OPEN EntityProperties_Cursor;

FETCH NEXT FROM EntityProperties_Cursor
INTO
    @Guid,
    @EP_RowStatus,
    @EP_Name,
    @EP_SourceLanguageLabelID,
    @EP_SourceEntityHoBTID,
    @EP_SourceEntityDataTypeID,
    @EP_IsReadOnly,
    @EP_IsImmutable,
    @EP_IsUppercase,
    @EP_IsHidden,
    @EP_IsCompulsory,
    @EP_MaxLength,
    @EP_Precision,
    @EP_Scale,
    @EP_DoNotTrackChanges,
    @EP_SourceEntityPropertyGroupID,
    @EP_SortOrder,
    @EP_GroupSortOrder,
    @EP_IsObjectLabel,
    @EP_SourceDropDownListDefinitionID,
    @EP_IsParentRelationship,
    @EP_IsIncludedInformation,
    @EP_IsLatitude,
    @EP_IsLongitude,
    @EP_FixDefaultValue,
    @EP_SqlDefaultValueStatement,
    @EP_AllowBulkChange,
    @EP_IsVirtual,
    @EP_ShowOnMobile,
    @EP_IsAlwaysVisibleInGroup,
    @EP_IsAlwaysVisibleInGroup_Mobile,
    @EP_SourceRowId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EP_LanguageLabelGuid = NULL;
    SET @EP_EntityHoBTGuid = NULL;
    SET @EP_EntityDataTypeGuid = NULL;
    SET @EP_EntityPropertyGroupGuid = NULL;
    SET @EP_DropDownListDefinitionGuid = NULL;
    SET @EP_FixDefaultValue = ISNULL(@EP_FixDefaultValue, N'');
    SELECT
        @EP_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @EP_SourceLanguageLabelID;

    SELECT
        @EP_EntityHoBTGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityHobts'
      AND lookup.SourceRowId = @EP_SourceEntityHoBTID;

    IF @EP_SourceEntityDataTypeID IS NULL OR @EP_SourceEntityDataTypeID <= 0
    BEGIN
        SET @EP_EntityDataTypeGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_EntityDataTypeGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityDataTypes'
          AND lookup.SourceRowId = @EP_SourceEntityDataTypeID;
    END;

    IF @EP_SourceEntityPropertyGroupID IS NULL OR @EP_SourceEntityPropertyGroupID <= 0
    BEGIN
        SET @EP_EntityPropertyGroupGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_EntityPropertyGroupGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityPropertyGroups'
          AND lookup.SourceRowId = @EP_SourceEntityPropertyGroupID;
    END;

    IF @EP_SourceDropDownListDefinitionID IS NULL OR @EP_SourceDropDownListDefinitionID <= 0
    BEGIN
        SET @EP_DropDownListDefinitionGuid = @ZeroGuid;
    END;
    ELSE
    BEGIN
        SELECT
            @EP_DropDownListDefinitionGuid = lookup.SourceRowGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'DropDownListDefinitions'
          AND lookup.SourceRowId = @EP_SourceDropDownListDefinitionID;
    END;

    IF @EP_EntityDataTypeGuid IS NULL
    BEGIN
        DECLARE @MissingEntityDataTypeMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityDataType source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityDataTypeID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityDataTypes is staged/applied before SCore.EntityProperties.');
        THROW 52022, @MissingEntityDataTypeMessage, 1;
    END;

    IF @EP_EntityPropertyGroupGuid IS NULL
    BEGIN
        DECLARE @MissingEntityPropertyGroupMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve EntityPropertyGroup source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceEntityPropertyGroupID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SCore.EntityPropertyGroups is staged/applied before SCore.EntityProperties.');
        THROW 52023, @MissingEntityPropertyGroupMessage, 1;
    END;

    IF @EP_DropDownListDefinitionGuid IS NULL
    BEGIN
        DECLARE @MissingDropDownListDefinitionMessage NVARCHAR(4000) = CONCAT(N'EntityProperties apply could not resolve DropDownListDefinition source ID ', COALESCE(CONVERT(NVARCHAR(30), @EP_SourceDropDownListDefinitionID), N'<NULL>'), N' for property ', COALESCE(@EP_Name, CONVERT(NVARCHAR(36), @Guid)), N'. Ensure SUserInterface.DropDownListDefinitions is applied before SCore.EntityProperties.');
        THROW 52024, @MissingDropDownListDefinitionMessage, 1;
    END;

    DECLARE @ExistingEntityPropertyGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @ExistingEntityPropertyGuid = ep.Guid
    FROM SCore.EntityProperties AS ep
    INNER JOIN SCore.EntityHobts AS eh
        ON eh.ID = ep.EntityHoBTID
       AND eh.RowStatus NOT IN (0,254)
    WHERE eh.Guid = @EP_EntityHoBTGuid
      AND ep.Name = @EP_Name
      AND ep.RowStatus NOT IN (0,254)
      AND ep.Guid <> @Guid
    ORDER BY ep.ID;

    DECLARE @EntityPropertyGuid UNIQUEIDENTIFIER = ISNULL(@ExistingEntityPropertyGuid, @Guid);

    IF @ExistingEntityPropertyGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingEntityPropertyGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SCore'
          AND lookup.TableName = N'EntityProperties'
          AND lookup.SourceRowId = @EP_SourceRowId;
    END;

    EXEC SCore.EntityPropertyUpsert
        @Name = @EP_Name,
        @RowStatus = @EP_RowStatus,
        @LanguageLabelGuid = @EP_LanguageLabelGuid,
        @EntityHobtGuid = @EP_EntityHoBTGuid,
        @EntityDataTypeGuid = @EP_EntityDataTypeGuid,
        @IsReadOnly = @EP_IsReadOnly,
        @IsImmutable = @EP_IsImmutable,
        @IsUppercase = @EP_IsUppercase,
        @IsHidden = @EP_IsHidden,
        @IsCompulsory = @EP_IsCompulsory,
        @MaxLength = @EP_MaxLength,
        @Precision = @EP_Precision,
        @Scale = @EP_Scale,
        @DoNotTrackChanges = @EP_DoNotTrackChanges,
        @EntityPropertyGroupGuid = @EP_EntityPropertyGroupGuid,
        @SortOrder = @EP_SortOrder,
        @GroupSortOrder = @EP_GroupSortOrder,
        @IsObjectLabel = @EP_IsObjectLabel,
        @DropDownListDefinitionGuid = @EP_DropDownListDefinitionGuid,
        @IsParentRelationship = @EP_IsParentRelationship,
        @IsIncludedInformation = @EP_IsIncludedInformation,
        @IsLatitude = @EP_IsLatitude,
        @IsLongitude = @EP_IsLongitude,
        @FixDefaultValue = @EP_FixDefaultValue,
        @SqlDefaultValueStatement = @EP_SqlDefaultValueStatement,
        @AllowBulkChange = @EP_AllowBulkChange,
        @IsVirtual = @EP_IsVirtual,
        @ShowOnMobile = @EP_ShowOnMobile,
        @IsAlwaysVisibleInGroup = @EP_IsAlwaysVisibleInGroup,
        @IsAlwaysVisibleInGroup_Mobile = @EP_IsAlwaysVisibleInGroup_Mobile,
        @Guid = @EntityPropertyGuid OUTPUT;

    FETCH NEXT FROM EntityProperties_Cursor
    INTO
        @Guid,
        @EP_RowStatus,
        @EP_Name,
        @EP_SourceLanguageLabelID,
        @EP_SourceEntityHoBTID,
        @EP_SourceEntityDataTypeID,
        @EP_IsReadOnly,
        @EP_IsImmutable,
        @EP_IsUppercase,
        @EP_IsHidden,
        @EP_IsCompulsory,
        @EP_MaxLength,
        @EP_Precision,
        @EP_Scale,
        @EP_DoNotTrackChanges,
        @EP_SourceEntityPropertyGroupID,
        @EP_SortOrder,
        @EP_GroupSortOrder,
        @EP_IsObjectLabel,
        @EP_SourceDropDownListDefinitionID,
        @EP_IsParentRelationship,
        @EP_IsIncludedInformation,
        @EP_IsLatitude,
        @EP_IsLongitude,
        @EP_FixDefaultValue,
        @EP_SqlDefaultValueStatement,
        @EP_AllowBulkChange,
        @EP_IsVirtual,
        @EP_ShowOnMobile,
        @EP_IsAlwaysVisibleInGroup,
        @EP_IsAlwaysVisibleInGroup_Mobile,
        @EP_SourceRowId;
END;

CLOSE EntityProperties_Cursor;
DEALLOCATE EntityProperties_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityProperties',
    @StepStatus = N'Succeeded',
    @Message = N'Entity properties applied.',
    @DetailsJson = N'{}';

/* =========================================================
   6. SCore.EntityQueryParameters
   ========================================================= */

DECLARE
    @EQP_RowStatus TINYINT,
    @EQP_Name NVARCHAR(500),
    @EQP_SourceEntityQueryID BIGINT,
    @EQP_SourceEntityDataTypeID BIGINT,
    @EQP_SourceMappedEntityPropertyID BIGINT,
    @EQP_EntityQueryGuid UNIQUEIDENTIFIER,
    @EQP_EntityDataTypeGuid UNIQUEIDENTIFIER,
    @EQP_MappedEntityPropertyGuid UNIQUEIDENTIFIER,
    @EQP_DefaultValue NVARCHAR(200),
    @EQP_IsInput BIT,
    @EQP_IsOutput BIT,
    @EQP_IsReturnColumn BIT;

DECLARE EntityQueryParameters_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityQueryId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityDataTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyID'), JSON_VALUE(sr.SourcePayloadJson, N'$.MappedEntityPropertyId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultValue'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsInput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsOutput')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsReturnColumn'))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SCore'
      AND tr.TableName = N'EntityQueryParameters'
    ORDER BY sr.SourceRowId;

OPEN EntityQueryParameters_Cursor;

FETCH NEXT FROM EntityQueryParameters_Cursor
INTO
    @Guid,
    @EQP_RowStatus,
    @EQP_Name,
    @EQP_SourceEntityQueryID,
    @EQP_SourceEntityDataTypeID,
    @EQP_SourceMappedEntityPropertyID,
    @EQP_DefaultValue,
    @EQP_IsInput,
    @EQP_IsOutput,
    @EQP_IsReturnColumn;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @EQP_EntityQueryGuid = NULL;
    SET @EQP_EntityDataTypeGuid = NULL;
    SET @EQP_MappedEntityPropertyGuid = NULL;
    SELECT
        @EQP_EntityQueryGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityQueries'
      AND lookup.SourceRowId = @EQP_SourceEntityQueryID;

    SELECT
        @EQP_EntityDataTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityDataTypes'
      AND lookup.SourceRowId = @EQP_SourceEntityDataTypeID;

    SELECT
        @EQP_MappedEntityPropertyGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityProperties'
      AND lookup.SourceRowId = @EQP_SourceMappedEntityPropertyID;

    DECLARE @EntityQueryParameterGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SCore.EntityQueryParameterUpsert
        @Name = @EQP_Name,
        @RowStatus = @EQP_RowStatus,
        @EntityQueryGuid = @EQP_EntityQueryGuid,
        @EntityDataTypeGuid = @EQP_EntityDataTypeGuid,
        @MappedEntityPropertyGuid = @EQP_MappedEntityPropertyGuid,
        @DefaultValue = @EQP_DefaultValue,
        @IsInput = @EQP_IsInput,
        @IsOutput = @EQP_IsOutput,
        @IsReturnColumn = @EQP_IsReturnColumn,
        @Guid = @EntityQueryParameterGuid OUTPUT;

    FETCH NEXT FROM EntityQueryParameters_Cursor
    INTO
        @Guid,
        @EQP_RowStatus,
        @EQP_Name,
        @EQP_SourceEntityQueryID,
        @EQP_SourceEntityDataTypeID,
        @EQP_SourceMappedEntityPropertyID,
        @EQP_DefaultValue,
        @EQP_IsInput,
        @EQP_IsOutput,
        @EQP_IsReturnColumn;
END;

CLOSE EntityQueryParameters_Cursor;
DEALLOCATE EntityQueryParameters_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyEntityQueryParameters',
    @StepStatus = N'Succeeded',
    @Message = N'Entity query parameters applied.',
    @DetailsJson = N'{}';


/* =========================================================
   7. SUserInterface.GridDefinitions
   ========================================================= */

DECLARE
    @GD_RowStatus TINYINT,
    @GD_Code NVARCHAR(30),
    @GD_TabName NVARCHAR(250),
    @GD_ShowAsTiles BIT,
    @GD_PageUri NVARCHAR(250),
    @GD_SourceLanguageLabelID BIGINT,
    @GD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TabName'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowAsTiles')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.PageUri'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId')))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridDefinitions_Cursor;

FETCH NEXT FROM GridDefinitions_Cursor
INTO
    @Guid,
    @GD_RowStatus,
    @GD_Code,
    @GD_TabName,
    @GD_ShowAsTiles,
    @GD_PageUri,
    @GD_SourceLanguageLabelID;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GD_LanguageLabelGuid = NULL;
    SELECT
        @GD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GD_SourceLanguageLabelID;

    DECLARE @GridDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridDefinitionUpsert
        @Code = @GD_Code,
        @RowStatus = @GD_RowStatus,
        @TabName = @GD_TabName,
        @ShowAsTiles = @GD_ShowAsTiles,
        @PageUri = @GD_PageUri,
        @LanguageLabelGuid = @GD_LanguageLabelGuid,
        @Guid = @GridDefinitionGuid OUTPUT;

    FETCH NEXT FROM GridDefinitions_Cursor
    INTO
        @Guid,
        @GD_RowStatus,
        @GD_Code,
        @GD_TabName,
        @GD_ShowAsTiles,
        @GD_PageUri,
        @GD_SourceLanguageLabelID;
END;

CLOSE GridDefinitions_Cursor;
DEALLOCATE GridDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   8. SUserInterface.GridViewDefinitions
   ========================================================= */

DECLARE
    @GVD_RowStatus TINYINT,
    @GVD_Code NVARCHAR(20),
    @GVD_SourceGridDefinitionID BIGINT,
    @GVD_DetailPageUri NVARCHAR(250),
    @GVD_SqlQuery NVARCHAR(MAX),
    @GVD_DefaultSortColumnName NVARCHAR(250),
    @GVD_SecurableCode NVARCHAR(20),
    @GVD_DisplayOrder INT,
    @GVD_DisplayGroupName NVARCHAR(50),
    @GVD_MetricSqlQuery NVARCHAR(MAX),
    @GVD_ShowMetric BIT,
    @GVD_IsDetailWindowed BIT,
    @GVD_SourceEntityTypeID BIGINT,
    @GVD_SourceMetricTypeID BIGINT,
    @GVD_MetricMin INT,
    @GVD_MetricMax INT,
    @GVD_MetricMinorUnit INT,
    @GVD_MetricMajorUnit INT,
    @GVD_MetricStartAngle INT,
    @GVD_MetricEndAngle INT,
    @GVD_MetricReversed BIT,
    @GVD_MetricRange1Min DECIMAL(18,0),
    @GVD_MetricRange1Max DECIMAL(18,0),
    @GVD_MetricRange1ColourHex NVARCHAR(10),
    @GVD_MetricRange2Min DECIMAL(18,0),
    @GVD_MetricRange2Max DECIMAL(18,0),
    @GVD_MetricRange2ColourHex NVARCHAR(10),
    @GVD_IsDefaultSortDescending BIT,
    @GVD_ShowOnMobile BIT,
    @GVD_AllowNew BIT,
    @GVD_AllowExcelExport BIT,
    @GVD_AllowPdfExport BIT,
    @GVD_AllowCsvExport BIT,
    @GVD_SourceLanguageLabelID BIGINT,
    @GVD_SourceDrawerIconID BIGINT,
    @GVD_SourceGridViewTypeID BIGINT,
    @GVD_AllowBulkChange BIT,
    @GVD_TreeListFirstOrderBy NVARCHAR(100),
    @GVD_TreeListSecondOrderBy NVARCHAR(100),
    @GVD_TreeListThirdOrderBy NVARCHAR(100),
    @GVD_TreeListOrderBy NVARCHAR(100),
    @GVD_TreeListGroupBy NVARCHAR(100),
    @GVD_ShowOnDashboard BIT,
    @GVD_FilteredListCreatedOnColumn NVARCHAR(100),
    @GVD_FilteredListRedStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListOrangeStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGreenStatusIndicatorTxt NVARCHAR(100),
    @GVD_FilteredListGroupBy NVARCHAR(100),
    @GVD_IsHidden BIT,
    @GVD_GridDefinitionGuid UNIQUEIDENTIFIER,
    @GVD_EntityTypeGuid UNIQUEIDENTIFIER,
    @GVD_MetricTypeGuid UNIQUEIDENTIFIER,
    @GVD_LanguageLabelGuid UNIQUEIDENTIFIER,
    @GVD_DrawerIconGuid UNIQUEIDENTIFIER,
    @GVD_GridViewTypeGuid UNIQUEIDENTIFIER;

DECLARE GridViewDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Code'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridDefinitionId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DetailPageUri'),
        jsonValues.SqlQuery,
        JSON_VALUE(sr.SourcePayloadJson, N'$.DefaultSortColumnName'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.SecurableCode'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayOrder')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayGroupName'),
        jsonValues.MetricSqlQuery,
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowMetric')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDetailWindowed')),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.EntityTypeId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricTypeId'))),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMin')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMax')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMinorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricMajorUnit')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricStartAngle')),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricEndAngle')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.MetricReversed')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange1ColourHex'),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Min')),
        TRY_CONVERT(DECIMAL(18,0), JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2Max')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.MetricRange2ColourHex'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsDefaultSortDescending')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnMobile')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowNew')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowExcelExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowPdfExport')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowCsvExport')),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconID'), JSON_VALUE(sr.SourcePayloadJson, N'$.DrawerIconId'))),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewTypeId'))),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.AllowBulkChange')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListFirstOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListSecondOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListThirdOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListOrderBy'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TreeListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.ShowOnDashboard')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListCreatedOnColumn'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListRedStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListOrangeStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGreenStatusIndicatorTxt'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.FilteredListGroupBy'),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden'))
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    CROSS APPLY OPENJSON(sr.SourcePayloadJson)
    WITH
    (
        SqlQuery NVARCHAR(MAX) N'$.SqlQuery',
        MetricSqlQuery NVARCHAR(MAX) N'$.MetricSqlQuery'
    ) AS jsonValues
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewDefinitions_Cursor;

FETCH NEXT FROM GridViewDefinitions_Cursor
INTO
    @Guid,
    @GVD_RowStatus,
    @GVD_Code,
    @GVD_SourceGridDefinitionID,
    @GVD_DetailPageUri,
    @GVD_SqlQuery,
    @GVD_DefaultSortColumnName,
    @GVD_SecurableCode,
    @GVD_DisplayOrder,
    @GVD_DisplayGroupName,
    @GVD_MetricSqlQuery,
    @GVD_ShowMetric,
    @GVD_IsDetailWindowed,
    @GVD_SourceEntityTypeID,
    @GVD_SourceMetricTypeID,
    @GVD_MetricMin,
    @GVD_MetricMax,
    @GVD_MetricMinorUnit,
    @GVD_MetricMajorUnit,
    @GVD_MetricStartAngle,
    @GVD_MetricEndAngle,
    @GVD_MetricReversed,
    @GVD_MetricRange1Min,
    @GVD_MetricRange1Max,
    @GVD_MetricRange1ColourHex,
    @GVD_MetricRange2Min,
    @GVD_MetricRange2Max,
    @GVD_MetricRange2ColourHex,
    @GVD_IsDefaultSortDescending,
    @GVD_ShowOnMobile,
    @GVD_AllowNew,
    @GVD_AllowExcelExport,
    @GVD_AllowPdfExport,
    @GVD_AllowCsvExport,
    @GVD_SourceLanguageLabelID,
    @GVD_SourceDrawerIconID,
    @GVD_SourceGridViewTypeID,
    @GVD_AllowBulkChange,
    @GVD_TreeListFirstOrderBy,
    @GVD_TreeListSecondOrderBy,
    @GVD_TreeListThirdOrderBy,
    @GVD_TreeListOrderBy,
    @GVD_TreeListGroupBy,
    @GVD_ShowOnDashboard,
    @GVD_FilteredListCreatedOnColumn,
    @GVD_FilteredListRedStatusIndicatorTxt,
    @GVD_FilteredListOrangeStatusIndicatorTxt,
    @GVD_FilteredListGreenStatusIndicatorTxt,
    @GVD_FilteredListGroupBy,
    @GVD_IsHidden;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVD_GridDefinitionGuid = NULL;
    SET @GVD_EntityTypeGuid = NULL;
    SET @GVD_MetricTypeGuid = NULL;
    SET @GVD_LanguageLabelGuid = NULL;
    SET @GVD_DrawerIconGuid = NULL;
    SET @GVD_GridViewTypeGuid = NULL;
    SELECT
        @GVD_GridDefinitionGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridDefinitions'
      AND lookup.SourceRowId = @GVD_SourceGridDefinitionID;

    SELECT
        @GVD_EntityTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'EntityTypes'
      AND lookup.SourceRowId = @GVD_SourceEntityTypeID;

    SELECT
        @GVD_MetricTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'MetricTypes'
      AND lookup.SourceRowId = @GVD_SourceMetricTypeID;

    SELECT
        @GVD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GVD_SourceLanguageLabelID;

    SELECT
        @GVD_DrawerIconGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'Icons'
      AND lookup.SourceRowId = @GVD_SourceDrawerIconID;

    SELECT
        @GVD_GridViewTypeGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridViewTypes'
      AND lookup.SourceRowId = @GVD_SourceGridViewTypeID;

    DECLARE @GridViewDefinitionGuid UNIQUEIDENTIFIER = @Guid;

    EXEC SUserInterface.GridViewDefinitionUpsert
        @Code = @GVD_Code,
        @RowStatus = @GVD_RowStatus,
        @GridDefinitionGuid = @GVD_GridDefinitionGuid,
        @DetailPageUri = @GVD_DetailPageUri,
        @SqlQuery = @GVD_SqlQuery,
        @DefaultSortColumnName = @GVD_DefaultSortColumnName,
        @SecurableCode = @GVD_SecurableCode,
        @DisplayOrder = @GVD_DisplayOrder,
        @DisplayGroupName = @GVD_DisplayGroupName,
        @MetricSqlQuery = @GVD_MetricSqlQuery,
        @ShowMetric = @GVD_ShowMetric,
        @IsDetailWindowed = @GVD_IsDetailWindowed,
        @EntityTypeGuid = @GVD_EntityTypeGuid,
        @MetricTypeGuid = @GVD_MetricTypeGuid,
        @MetricMin = @GVD_MetricMin,
        @MetricMax = @GVD_MetricMax,
        @MetricMinorUnit = @GVD_MetricMinorUnit,
        @MetricMajorUnit = @GVD_MetricMajorUnit,
        @MetricStartAngle = @GVD_MetricStartAngle,
        @MetricEndAngle = @GVD_MetricEndAngle,
        @MetricReversed = @GVD_MetricReversed,
        @MetricRange1Min = @GVD_MetricRange1Min,
        @MetricRange1Max = @GVD_MetricRange1Max,
        @MetricRange1ColourHex = @GVD_MetricRange1ColourHex,
        @MetricRange2Min = @GVD_MetricRange2Min,
        @MetricRange2Max = @GVD_MetricRange2Max,
        @MetricRange2ColourHex = @GVD_MetricRange2ColourHex,
        @IsDefaultSortDescending = @GVD_IsDefaultSortDescending,
        @AllowNew = @GVD_AllowNew,
        @AllowExcelExport = @GVD_AllowExcelExport,
        @AllowPdfExport = @GVD_AllowPdfExport,
        @AllowCsvExport = @GVD_AllowCsvExport,
        @LanguageLabelGuid = @GVD_LanguageLabelGuid,
        @DrawerIconGuid = @GVD_DrawerIconGuid,
        @GridViewTypeGuid = @GVD_GridViewTypeGuid,
        @AllowBulkChange = @GVD_AllowBulkChange,
        @Guid = @GridViewDefinitionGuid OUTPUT,
        @ShowOnMobile = @GVD_ShowOnMobile,
        @TreeListFirstOrderBy = @GVD_TreeListFirstOrderBy,
        @TreeListSecondOrderBy = @GVD_TreeListSecondOrderBy,
        @TreeListThirdOrderBy = @GVD_TreeListThirdOrderBy,
        @TreeListOrderBy = @GVD_TreeListOrderBy,
        @TreeListGroupBy = @GVD_TreeListGroupBy,
        @ShowOnDashboard = @GVD_ShowOnDashboard,
        @FilteredListCreatedOnColumn = @GVD_FilteredListCreatedOnColumn,
        @FilteredListRedStatusIndicatorTxt = @GVD_FilteredListRedStatusIndicatorTxt,
        @FilteredListOrangeStatusIndicatorTxt = @GVD_FilteredListOrangeStatusIndicatorTxt,
        @FilteredListGreenStatusIndicatorTxt = @GVD_FilteredListGreenStatusIndicatorTxt,
        @FilteredListGroupBy = @GVD_FilteredListGroupBy,
        @IsHidden = @GVD_IsHidden;

    FETCH NEXT FROM GridViewDefinitions_Cursor
    INTO
        @Guid,
        @GVD_RowStatus,
        @GVD_Code,
        @GVD_SourceGridDefinitionID,
        @GVD_DetailPageUri,
        @GVD_SqlQuery,
        @GVD_DefaultSortColumnName,
        @GVD_SecurableCode,
        @GVD_DisplayOrder,
        @GVD_DisplayGroupName,
        @GVD_MetricSqlQuery,
        @GVD_ShowMetric,
        @GVD_IsDetailWindowed,
        @GVD_SourceEntityTypeID,
        @GVD_SourceMetricTypeID,
        @GVD_MetricMin,
        @GVD_MetricMax,
        @GVD_MetricMinorUnit,
        @GVD_MetricMajorUnit,
        @GVD_MetricStartAngle,
        @GVD_MetricEndAngle,
        @GVD_MetricReversed,
        @GVD_MetricRange1Min,
        @GVD_MetricRange1Max,
        @GVD_MetricRange1ColourHex,
        @GVD_MetricRange2Min,
        @GVD_MetricRange2Max,
        @GVD_MetricRange2ColourHex,
        @GVD_IsDefaultSortDescending,
        @GVD_ShowOnMobile,
        @GVD_AllowNew,
        @GVD_AllowExcelExport,
        @GVD_AllowPdfExport,
        @GVD_AllowCsvExport,
        @GVD_SourceLanguageLabelID,
        @GVD_SourceDrawerIconID,
        @GVD_SourceGridViewTypeID,
        @GVD_AllowBulkChange,
        @GVD_TreeListFirstOrderBy,
        @GVD_TreeListSecondOrderBy,
        @GVD_TreeListThirdOrderBy,
        @GVD_TreeListOrderBy,
        @GVD_TreeListGroupBy,
        @GVD_ShowOnDashboard,
        @GVD_FilteredListCreatedOnColumn,
        @GVD_FilteredListRedStatusIndicatorTxt,
        @GVD_FilteredListOrangeStatusIndicatorTxt,
        @GVD_FilteredListGreenStatusIndicatorTxt,
        @GVD_FilteredListGroupBy,
        @GVD_IsHidden;
END;

CLOSE GridViewDefinitions_Cursor;
DEALLOCATE GridViewDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   9. SUserInterface.GridViewColumnDefinitions
   ========================================================= */

DECLARE
    @GVCD_RowStatus TINYINT,
    @GVCD_Name NVARCHAR(250),
    @GVCD_SourceGridViewDefinitionID BIGINT,
    @GVCD_ColumnOrder INT,
    @GVCD_IsPrimaryKey BIT,
    @GVCD_IsHidden BIT,
    @GVCD_IsFiltered BIT,
    @GVCD_IsCombo BIT,
    @GVCD_DisplayFormat NVARCHAR(50),
    @GVCD_Width NVARCHAR(10),
    @GVCD_SourceLanguageLabelID BIGINT,
    @GVCD_TopHeaderCategory NVARCHAR(50),
    @GVCD_TopHeaderCategoryOrder INT,
    @GVCD_SourceRowId BIGINT,
    @GVCD_GridViewDefinitionGuid UNIQUEIDENTIFIER,
    @GVCD_LanguageLabelGuid UNIQUEIDENTIFIER;

DECLARE GridViewColumnDefinitions_Cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT
        sr.SourceRowGuid,
        TRY_CONVERT(TINYINT, JSON_VALUE(sr.SourcePayloadJson, N'$.RowStatus')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Name'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionID'), JSON_VALUE(sr.SourcePayloadJson, N'$.GridViewDefinitionId'))),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.ColumnOrder')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsPrimaryKey')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsHidden')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsFiltered')),
        TRY_CONVERT(BIT, JSON_VALUE(sr.SourcePayloadJson, N'$.IsCombo')),
        JSON_VALUE(sr.SourcePayloadJson, N'$.DisplayFormat'),
        JSON_VALUE(sr.SourcePayloadJson, N'$.Width'),
        TRY_CONVERT(BIGINT, COALESCE(JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelID'), JSON_VALUE(sr.SourcePayloadJson, N'$.LanguageLabelId'))),
        JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategory'),
        TRY_CONVERT(INT, JSON_VALUE(sr.SourcePayloadJson, N'$.TopHeaderCategoryOrder')),
        sr.SourceRowId
    FROM SMigration.Metadata_StagedRows AS sr
        INNER JOIN #MetadataRowsToApply AS applyRows
            ON applyRows.StagedRowId = sr.ID
    INNER JOIN SMigration.Metadata_TableRegistry AS tr
        ON tr.Guid = sr.RegistryGuid
       AND tr.RowStatus NOT IN (0,254)
    WHERE sr.RunGuid = @RunGuid
      AND sr.RowStatus NOT IN (0,254)
      AND sr.DifferenceType IN (N'Insert', N'Update')
      AND tr.SchemaName = N'SUserInterface'
      AND tr.TableName = N'GridViewColumnDefinitions'
    ORDER BY sr.SourceRowId;

OPEN GridViewColumnDefinitions_Cursor;

FETCH NEXT FROM GridViewColumnDefinitions_Cursor
INTO
    @Guid,
    @GVCD_RowStatus,
    @GVCD_Name,
    @GVCD_SourceGridViewDefinitionID,
    @GVCD_ColumnOrder,
    @GVCD_IsPrimaryKey,
    @GVCD_IsHidden,
    @GVCD_IsFiltered,
    @GVCD_IsCombo,
    @GVCD_DisplayFormat,
    @GVCD_Width,
    @GVCD_SourceLanguageLabelID,
    @GVCD_TopHeaderCategory,
    @GVCD_TopHeaderCategoryOrder,
    @GVCD_SourceRowId;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @GVCD_GridViewDefinitionGuid = NULL;
    SET @GVCD_LanguageLabelGuid = NULL;
    SELECT
        @GVCD_GridViewDefinitionGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SUserInterface'
      AND lookup.TableName = N'GridViewDefinitions'
      AND lookup.SourceRowId = @GVCD_SourceGridViewDefinitionID;

    SELECT
        @GVCD_LanguageLabelGuid = lookup.SourceRowGuid
    FROM #MetadataSourceGuidLookup AS lookup
    WHERE lookup.SchemaName = N'SCore'
      AND lookup.TableName = N'LanguageLabels'
      AND lookup.SourceRowId = @GVCD_SourceLanguageLabelID;

    DECLARE @ExistingGridViewColumnDefinitionGuid UNIQUEIDENTIFIER = NULL;

    SELECT TOP (1)
        @ExistingGridViewColumnDefinitionGuid = gvcd.Guid
    FROM SUserInterface.GridViewColumnDefinitions AS gvcd
    INNER JOIN SUserInterface.GridViewDefinitions AS gvd
        ON gvd.ID = gvcd.GridViewDefinitionID
       AND gvd.RowStatus NOT IN (0,254)
    WHERE gvd.Guid = @GVCD_GridViewDefinitionGuid
      AND gvcd.RowStatus NOT IN (0,254)
      AND gvcd.Guid <> @Guid
      AND
      (
          (
              ISNULL(@GVCD_IsPrimaryKey, 0) = 1
              AND gvcd.IsPrimaryKey = 1
          )
          OR
          (
              ISNULL(@GVCD_IsPrimaryKey, 0) = 0
              AND gvcd.Name = @GVCD_Name
          )
      )
    ORDER BY
        CASE WHEN ISNULL(@GVCD_IsPrimaryKey, 0) = 1 AND gvcd.IsPrimaryKey = 1 THEN 0 ELSE 1 END,
        gvcd.ID;

    DECLARE @GridViewColumnDefinitionGuid UNIQUEIDENTIFIER = ISNULL(@ExistingGridViewColumnDefinitionGuid, @Guid);

    IF @ExistingGridViewColumnDefinitionGuid IS NOT NULL
    BEGIN
        UPDATE lookup
        SET SourceRowGuid = @ExistingGridViewColumnDefinitionGuid
        FROM #MetadataSourceGuidLookup AS lookup
        WHERE lookup.SchemaName = N'SUserInterface'
          AND lookup.TableName = N'GridViewColumnDefinitions'
          AND lookup.SourceRowId = @GVCD_SourceRowId;
    END;

    EXEC SUserInterface.GridViewColumnDefinitionUpsert
        @Name = @GVCD_Name,
        @RowStatus = @GVCD_RowStatus,
        @GridViewDefinitionGuid = @GVCD_GridViewDefinitionGuid,
        @ColumnOrder = @GVCD_ColumnOrder,
        @IsPrimaryKey = @GVCD_IsPrimaryKey,
        @IsHidden = @GVCD_IsHidden,
        @IsFiltered = @GVCD_IsFiltered,
        @IsCombo = @GVCD_IsCombo,
        @DisplayFormat = @GVCD_DisplayFormat,
        @Width = @GVCD_Width,
        @LanguageLabelGuid = @GVCD_LanguageLabelGuid,
        @Guid = @GridViewColumnDefinitionGuid OUTPUT,
        @TopHeaderCategory = @GVCD_TopHeaderCategory,
        @TopHeaderCategoryOrder = @GVCD_TopHeaderCategoryOrder;

    FETCH NEXT FROM GridViewColumnDefinitions_Cursor
    INTO
        @Guid,
        @GVCD_RowStatus,
        @GVCD_Name,
        @GVCD_SourceGridViewDefinitionID,
        @GVCD_ColumnOrder,
        @GVCD_IsPrimaryKey,
        @GVCD_IsHidden,
        @GVCD_IsFiltered,
        @GVCD_IsCombo,
        @GVCD_DisplayFormat,
        @GVCD_Width,
        @GVCD_SourceLanguageLabelID,
        @GVCD_TopHeaderCategory,
        @GVCD_TopHeaderCategoryOrder,
        @GVCD_SourceRowId;
END;

CLOSE GridViewColumnDefinitions_Cursor;
DEALLOCATE GridViewColumnDefinitions_Cursor;

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyGridViewColumnDefinitions',
    @StepStatus = N'Succeeded',
    @Message = N'Grid view column definitions applied.',
    @DetailsJson = N'{}';

/* =========================================================
   11. Labels
   ========================================================= */

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyLabels',
    @StepStatus = N'Succeeded',
    @Message = N'Labels are applied through SCore.LanguageLabels and SCore.LanguageLabelTranslations handlers.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations"]}';

UPDATE SMigration.Metadata_Run
SET
    RunStatus = N'AppliedUiMetadata',
    AppliedOnUtc = SYSUTCDATETIME()
WHERE Guid = @RunGuid
  AND RowStatus NOT IN (0,254);

EXEC SMigration.MetadataExecutionLog_Add
    @RunGuid = @RunGuid,
    @StepName = N'ApplyMetadataComplete',
    @StepStatus = N'Succeeded',
    @Message = N'Core and UI metadata apply handlers completed.',
    @DetailsJson = N'{"AppliedTables":["SCore.LanguageLabels","SCore.LanguageLabelTranslations","SCore.EntityDataTypes","SUserInterface.Icons","SCore.EntityTypes","SCore.EntityHobts","SUserInterface.DropDownListDefinitions","SCore.EntityPropertyGroups","SCore.EntityQueries","SCore.EntityProperties","SCore.EntityQueryParameters","SUserInterface.GridDefinitions","SUserInterface.GridViewDefinitions","SUserInterface.GridViewColumnDefinitions"]}';

COMMIT TRANSACTION;
END;

GO

