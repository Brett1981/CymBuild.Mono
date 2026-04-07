PRINT (N'Create table [SCore].[DataObjectIntegrityFindings]')
GO
CREATE TABLE [SCore].[DataObjectIntegrityFindings] (
  [FindingRunGuid] [uniqueidentifier] NOT NULL,
  [LoggedAtUtc] [datetime2] NOT NULL CONSTRAINT [DF_DataObjectIntegrityFindings_LoggedAtUtc] DEFAULT (sysutcdatetime()),
  [FindingType] [nvarchar](20) NOT NULL,
  [EntityTypeId] [int] NULL,
  [SchemaName] [sysname] NULL,
  [TableName] [sysname] NULL,
  [EntityGuid] [uniqueidentifier] NULL,
  [DataObjectGuid] [uniqueidentifier] NULL,
  [DataObjectRowStatus] [tinyint] NULL,
  [Details] [nvarchar](4000) NULL
)
ON [PRIMARY]
GO

PRINT (N'Create index [IX_DataObjectIntegrityFindings_Run] on table [SCore].[DataObjectIntegrityFindings]')
GO
CREATE INDEX [IX_DataObjectIntegrityFindings_Run]
  ON [SCore].[DataObjectIntegrityFindings] ([FindingRunGuid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO