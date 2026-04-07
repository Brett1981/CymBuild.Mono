CREATE TABLE [SCore].[DataObjects] (
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_DataObjects_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_DataObjects_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [EntityTypeId] [int] NOT NULL,
  CONSTRAINT [PK_DataObjects] PRIMARY KEY CLUSTERED ([Guid]) WITH (PAD_INDEX = ON, FILLFACTOR = 80, ALLOW_PAGE_LOCKS = OFF)
)
ON [PRIMARY]
GO

ALTER TABLE [SCore].[DataObjects]
  ADD CONSTRAINT [FK_DataObjects_EntityTypes] FOREIGN KEY ([EntityTypeId]) REFERENCES [SCore].[EntityTypes] ([ID])
GO