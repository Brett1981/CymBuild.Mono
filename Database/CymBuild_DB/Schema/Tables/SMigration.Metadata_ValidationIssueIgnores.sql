PRINT (N'Create table [SMigration].[Metadata_ValidationIssueIgnores]')
GO

CREATE TABLE [SMigration].[Metadata_ValidationIssueIgnores]
(
    [ID] [bigint] IDENTITY NOT NULL,
    [Guid] [uniqueidentifier] NOT NULL,
    [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Metadata_ValidationIssueIgnores_RowStatus] DEFAULT (1),
    [DatabaseName] [sysname] NOT NULL,
    [ServerName] [nvarchar](255) NOT NULL CONSTRAINT [DF_Metadata_ValidationIssueIgnores_ServerName] DEFAULT (N''),
    [EnvironmentName] [nvarchar](20) NOT NULL CONSTRAINT [DF_Metadata_ValidationIssueIgnores_EnvironmentName] DEFAULT (N''),
    [RegistryGuid] [uniqueidentifier] NOT NULL,
    [SchemaName] [nvarchar](128) NOT NULL,
    [TableName] [nvarchar](128) NOT NULL,
    [SourceRowGuid] [uniqueidentifier] NOT NULL,
    [IssueCode] [nvarchar](100) NOT NULL,
    [StableIssueKey] [nvarchar](800) NOT NULL,
    [Reason] [nvarchar](500) NOT NULL,
    [IgnoredByUserId] [int] NOT NULL CONSTRAINT [DF_Metadata_ValidationIssueIgnores_IgnoredByUserId] DEFAULT (-1),
    [IgnoredOnUtc] [datetime2](7) NOT NULL CONSTRAINT [DF_Metadata_ValidationIssueIgnores_IgnoredOnUtc] DEFAULT (SYSUTCDATETIME()),
    [UnignoredByUserId] [int] NULL,
    [UnignoredOnUtc] [datetime2](7) NULL,
    [LastSeenRunGuid] [uniqueidentifier] NULL,
    [LastSeenOnUtc] [datetime2](7) NULL,
    CONSTRAINT [PK_Metadata_ValidationIssueIgnores] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80),
    CONSTRAINT [UQ_Metadata_ValidationIssueIgnores_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

CREATE INDEX [IX_Metadata_ValidationIssueIgnores_DatabaseTable]
    ON [SMigration].[Metadata_ValidationIssueIgnores]
    (
        [DatabaseName],
        [SchemaName],
        [TableName],
        [RowStatus]
    )
    INCLUDE
    (
        [RegistryGuid],
        [SourceRowGuid],
        [IssueCode],
        [Reason],
        [IgnoredOnUtc]
    )
    WITH (FILLFACTOR = 80)
    ON [PRIMARY]
GO

CREATE UNIQUE INDEX [UX_Metadata_ValidationIssueIgnores_ActiveScope]
    ON [SMigration].[Metadata_ValidationIssueIgnores]
    (
        [DatabaseName],
        [RegistryGuid],
        [SourceRowGuid],
        [IssueCode]
    )
    WHERE [RowStatus] <> 0 AND [RowStatus] <> 254
    WITH (FILLFACTOR = 80)
    ON [PRIMARY]
GO
