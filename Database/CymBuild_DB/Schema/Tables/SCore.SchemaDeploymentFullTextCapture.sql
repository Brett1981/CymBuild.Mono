PRINT (N'Create table [SCore].[SchemaDeploymentFullTextCapture]')
GO
CREATE TABLE [SCore].[SchemaDeploymentFullTextCapture] (
  [ID] [int] IDENTITY,
  [ComparisonGuid] [uniqueidentifier] NOT NULL,
  [SchemaName] [sysname] NOT NULL,
  [TableName] [sysname] NOT NULL,
  [ConstraintName] [sysname] NOT NULL,
  [CatalogName] [sysname] NULL,
  [ChangeTrackingState] [nvarchar](20) NOT NULL,
  [StopListClause] [nvarchar](300) NOT NULL,
  [ColumnsClause] [nvarchar](max) NOT NULL,
  [CapturedUtc] [datetime2] NOT NULL CONSTRAINT [DF_SchemaDeploymentFullTextCapture_CapturedUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SchemaDeploymentFullTextCapture] on table [SCore].[SchemaDeploymentFullTextCapture]')
GO
ALTER TABLE [SCore].[SchemaDeploymentFullTextCapture] WITH NOCHECK
  ADD CONSTRAINT [PK_SchemaDeploymentFullTextCapture] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique index [IX_UQ_SchemaDeploymentFullTextCapture_Table] on table [SCore].[SchemaDeploymentFullTextCapture]')
GO
CREATE UNIQUE INDEX [IX_UQ_SchemaDeploymentFullTextCapture_Table]
  ON [SCore].[SchemaDeploymentFullTextCapture] ([SchemaName], [TableName])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO
