PRINT (N'Create table [SCore].[DataObjects]')
GO
CREATE TABLE [SCore].[DataObjects] (
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_DataObjects_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_DataObjects_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [EntityTypeId] [int] NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_DataObjects] on table [SCore].[DataObjects]')
GO
ALTER TABLE [SCore].[DataObjects] WITH NOCHECK
  ADD CONSTRAINT [PK_DataObjects] PRIMARY KEY CLUSTERED ([Guid]) WITH (PAD_INDEX = ON, FILLFACTOR = 80, ALLOW_PAGE_LOCKS = OFF)
GO

PRINT (N'Create foreign key [FK_DataObjects_EntityTypes] on table [SCore].[DataObjects]')
GO
ALTER TABLE [SCore].[DataObjects] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjects_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO