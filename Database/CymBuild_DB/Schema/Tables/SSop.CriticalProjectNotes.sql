PRINT (N'Create table [SSop].[CriticalProjectNotes]')
GO
CREATE TABLE [SSop].[CriticalProjectNotes] (
  [ID] [int] IDENTITY,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_CriticalProjectNotes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ProjectId] [int] NOT NULL CONSTRAINT [DF_CriticalProjectNotes_ProjectId] DEFAULT (-1),
  [DateCreated] [datetime2] NOT NULL CONSTRAINT [DF_CriticalProjectNotes_DateCreated] DEFAULT (sysutcdatetime()),
  [Note] [nvarchar](max) NULL,
  [CreatedBy] [int] NOT NULL CONSTRAINT [DF_CriticalProjectNotes_CreatedBy] DEFAULT (-1),
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_CriticalProjectNotes_RowStatus] DEFAULT (0),
  [ParentGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_CriticalProjectNotes_ParentGuid] DEFAULT ('00000000-0000-0000-0000-000000000000')
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_CriticalProjectNotes_CreatedBy] on table [SSop].[CriticalProjectNotes]')
GO
ALTER TABLE [SSop].[CriticalProjectNotes] WITH NOCHECK
  ADD CONSTRAINT [FK_CriticalProjectNotes_CreatedBy] FOREIGN KEY ([CreatedBy]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_CriticalProjectNotes_Guid] on table [SSop].[CriticalProjectNotes]')
GO
ALTER TABLE [SSop].[CriticalProjectNotes] WITH NOCHECK
  ADD CONSTRAINT [FK_CriticalProjectNotes_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Create foreign key [FK_CriticalProjectNotes_Projects] on table [SSop].[CriticalProjectNotes]')
GO
ALTER TABLE [SSop].[CriticalProjectNotes] WITH NOCHECK
  ADD CONSTRAINT [FK_CriticalProjectNotes_Projects] FOREIGN KEY ([ProjectId]) REFERENCES [SSop].[Projects] ([ID])
GO