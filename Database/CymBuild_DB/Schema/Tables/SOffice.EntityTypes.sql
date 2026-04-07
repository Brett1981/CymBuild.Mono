PRINT (N'Create table [SOffice].[EntityTypes]')
GO
CREATE TABLE [SOffice].[EntityTypes] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_EntityTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_EntityTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DF_EntityTypes_Name] DEFAULT ('')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_EntityTypes] on table [SOffice].[EntityTypes]')
GO
ALTER TABLE [SOffice].[EntityTypes] WITH NOCHECK
  ADD CONSTRAINT [PK_EntityTypes] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 90)
GO

PRINT (N'Create index [IX_EntityTypes_Guid] on table [SOffice].[EntityTypes]')
GO
CREATE UNIQUE INDEX [IX_EntityTypes_Guid]
  ON [SOffice].[EntityTypes] ([Guid])
  INCLUDE ([Name])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO