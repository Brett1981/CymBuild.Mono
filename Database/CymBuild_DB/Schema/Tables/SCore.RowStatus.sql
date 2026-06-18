PRINT (N'Create table [SCore].[RowStatus]')
GO
CREATE TABLE [SCore].[RowStatus] (
  [ID] [tinyint] NOT NULL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_RowStatus_Name] DEFAULT ('')
)
ON [METADATA]
GO

PRINT (N'Create primary key [PK_RowStatus] on table [SCore].[RowStatus]')
GO
ALTER TABLE [SCore].[RowStatus] WITH NOCHECK
  ADD CONSTRAINT [PK_RowStatus] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
GO

PRINT (N'Create index [IX_UQ_RowStatus_Name] on table [SCore].[RowStatus]')
GO
CREATE UNIQUE INDEX [IX_UQ_RowStatus_Name]
  ON [SCore].[RowStatus] ([Name])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO