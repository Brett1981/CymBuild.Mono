PRINT (N'Create table [SCore].[DataObjectEntityRegistry]')
GO
CREATE TABLE [SCore].[DataObjectEntityRegistry] (
  [EntityTypeId] [int] NOT NULL,
  [SchemaName] [sysname] NOT NULL,
  [TableName] [sysname] NOT NULL,
  [GuidColumn] [sysname] NOT NULL DEFAULT (N'Guid'),
  [RowStatusColumn] [sysname] NULL,
  [ActiveRowStatusCsv] [nvarchar](50) NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SCore].[DataObjectEntityRegistry]')
GO
ALTER TABLE [SCore].[DataObjectEntityRegistry] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([EntityTypeId]) WITH (FILLFACTOR = 90)
GO