PRINT (N'Create table [SCore].[DataObjectTransition]')
GO
CREATE TABLE [SCore].[DataObjectTransition] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_DataObjectTransition_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [StatusID] [int] NOT NULL CONSTRAINT [DF_DataObjectTransition_StatusID] DEFAULT (-1),
  [OldStatusID] [int] NULL,
  [Comment] [nvarchar](max) NULL,
  [DateTimeUTC] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
  [CreatedByUserId] [int] NOT NULL CONSTRAINT [DF_DataObjectTransition_CreatedByUserId] DEFAULT (-1),
  [SurveyorUserId] [int] NULL,
  [DataObjectGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_DataObjectTransition_DataObjectGuid] DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [IsImported] [bit] NOT NULL CONSTRAINT [DF_WorkflowTransition_IsImported] DEFAULT (0)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_DataObjectTransition_DataObjectGuid_IdDesc] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_DataObjectTransition_DataObjectGuid_IdDesc]
  ON [SCore].[DataObjectTransition] ([DataObjectGuid], [ID] DESC)
  INCLUDE ([RowStatus], [StatusID], [OldStatusID], [DateTimeUTC], [Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_DataObjectTransition_DataObjectGuid_Status_Date] on table [SCore].[DataObjectTransition]')
GO
CREATE INDEX [IX_DataObjectTransition_DataObjectGuid_Status_Date]
  ON [SCore].[DataObjectTransition] ([DataObjectGuid], [StatusID], [DateTimeUTC])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_CreatedBy] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_CreatedBy] FOREIGN KEY ([CreatedByUserId]) REFERENCES [SCore].[Identities] ([ID])
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_DataObjects] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_DataObjects] FOREIGN KEY ([DataObjectGuid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_DataObjectTransition_DataObjects] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition]
  NOCHECK CONSTRAINT [FK_DataObjectTransition_DataObjects]
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_OldStatus] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_OldStatus] FOREIGN KEY ([OldStatusID]) REFERENCES [SCore].[WorkflowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_Status] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_Status] FOREIGN KEY ([StatusID]) REFERENCES [SCore].[WorkflowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_DataObjectTransition_Surveyor] on table [SCore].[DataObjectTransition]')
GO
ALTER TABLE [SCore].[DataObjectTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_DataObjectTransition_Surveyor] FOREIGN KEY ([SurveyorUserId]) REFERENCES [SCore].[Identities] ([ID])
GO