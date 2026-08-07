SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SMigration].[Schema_ExcludedObjects] when missing')
GO

IF SCHEMA_ID(N'SMigration') IS NULL
    THROW 51400, 'Table [SMigration].[Schema_ExcludedObjects] requires schema [SMigration].', 1;
GO

IF OBJECT_ID(N'[SMigration].[Schema_ExcludedObjects]', N'U') IS NULL
BEGIN
    CREATE TABLE [SMigration].[Schema_ExcludedObjects]
    (
        [ID] [bigint] IDENTITY(1,1) NOT NULL,
        [Guid] [uniqueidentifier] NOT NULL,
        [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_RowStatus] DEFAULT (1),
        [StableObjectKey] [nvarchar](1300) NOT NULL,
        [StableObjectKeyHash] [binary](32) NOT NULL,
        [ObjectType] [nvarchar](50) NOT NULL,
        [SchemaName] [nvarchar](128) NOT NULL,
        [ObjectName] [nvarchar](512) NOT NULL,
        [ParentObjectName] [nvarchar](512) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_ParentObjectName] DEFAULT (N''),
        [ExclusionScope] [nvarchar](30) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_ExclusionScope] DEFAULT (N'AllDatabases'),
        [Reason] [nvarchar](2000) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_Reason] DEFAULT (N''),
        [OriginServerName] [nvarchar](255) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_OriginServerName] DEFAULT (N''),
        [OriginDatabaseName] [nvarchar](255) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_OriginDatabaseName] DEFAULT (N''),
        [ExcludedByUserId] [int] NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_ExcludedByUserId] DEFAULT (-1),
        [ExcludedOnUtc] [datetime2](7) NOT NULL CONSTRAINT [DF_Schema_ExcludedObjects_ExcludedOnUtc] DEFAULT (SYSUTCDATETIME()),
        [UnexcludedByUserId] [int] NULL,
        [UnexcludedOnUtc] [datetime2](7) NULL,
        [LastSeenRunGuid] [uniqueidentifier] NULL,
        [LastSeenOnUtc] [datetime2](7) NULL,
        CONSTRAINT [PK_Schema_ExcludedObjects] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
        CONSTRAINT [UQ_Schema_ExcludedObjects_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
    ) ON [PRIMARY];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS indexDefinition
    WHERE indexDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ExcludedObjects]', N'U')
      AND indexDefinition.[name] = N'UX_Schema_ExcludedObjects_StableObjectKeyHash'
)
BEGIN
    CREATE UNIQUE INDEX [UX_Schema_ExcludedObjects_StableObjectKeyHash]
        ON [SMigration].[Schema_ExcludedObjects] ([StableObjectKeyHash])
        WITH (FILLFACTOR = 80)
        ON [PRIMARY];
END;
GO

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes AS indexDefinition
    WHERE indexDefinition.[object_id] = OBJECT_ID(N'[SMigration].[Schema_ExcludedObjects]', N'U')
      AND indexDefinition.[name] = N'IX_Schema_ExcludedObjects_Active'
)
BEGIN
    CREATE INDEX [IX_Schema_ExcludedObjects_Active]
        ON [SMigration].[Schema_ExcludedObjects]
        (
            [ObjectType],
            [SchemaName]
        )
        INCLUDE
        (
            [ObjectName],
            [ParentObjectName],
            [StableObjectKey],
            [Reason],
            [ExclusionScope]
        )
        WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
        WITH (FILLFACTOR = 80)
        ON [PRIMARY];
END;
GO
