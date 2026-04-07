PRINT (N'Create table [SCore].[DataObjectEntityTypeConflictIgnores]')
GO
CREATE TABLE [SCore].[DataObjectEntityTypeConflictIgnores] (
  [ID] [int] IDENTITY,
  [CreatedAtUtc] [datetime2] NOT NULL CONSTRAINT [DF_DOETCI_CreatedAtUtc] DEFAULT (sysutcdatetime()),
  [CreatedBy] [sysname] NOT NULL CONSTRAINT [DF_DOETCI_CreatedBy] DEFAULT (suser_sname()),
  [ExpectedEntityTypeId] [int] NOT NULL,
  [ActualEntityTypeId] [int] NOT NULL,
  [EntityGuid] [uniqueidentifier] NOT NULL,
  [SchemaName] [sysname] NOT NULL,
  [TableName] [sysname] NOT NULL,
  [Reason] [nvarchar](4000) NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_DataObjectEntityTypeConflictIgnores] on table [SCore].[DataObjectEntityTypeConflictIgnores]')
GO
ALTER TABLE [SCore].[DataObjectEntityTypeConflictIgnores] WITH NOCHECK
  ADD CONSTRAINT [PK_DataObjectEntityTypeConflictIgnores] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create index [IX_DOETCI_Guid] on table [SCore].[DataObjectEntityTypeConflictIgnores]')
GO
CREATE INDEX [IX_DOETCI_Guid]
  ON [SCore].[DataObjectEntityTypeConflictIgnores] ([EntityGuid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_DOETCI_Pair] on table [SCore].[DataObjectEntityTypeConflictIgnores]')
GO
CREATE INDEX [IX_DOETCI_Pair]
  ON [SCore].[DataObjectEntityTypeConflictIgnores] ([ExpectedEntityTypeId], [ActualEntityTypeId])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO