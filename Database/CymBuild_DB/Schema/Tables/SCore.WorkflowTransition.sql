PRINT (N'Create table [SCore].[WorkflowTransition]')
GO
CREATE TABLE [SCore].[WorkflowTransition] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF__WorkflowT__RowSt__75E5CF3D] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NULL,
  [WorkflowID] [int] NOT NULL CONSTRAINT [DF_WorkflowTransition_WorkflowID] DEFAULT (-1),
  [FromStatusID] [int] NOT NULL CONSTRAINT [DF_WorkflowTransition_FromStatusID] DEFAULT (-1),
  [ToStatusID] [int] NOT NULL CONSTRAINT [DF_WorkflowTransition_ToStatusID] DEFAULT (-1),
  [IsFinal] [bit] NOT NULL CONSTRAINT [DF__WorkflowT__IsFin__76D9F376] DEFAULT (0),
  [Enabled] [bit] NOT NULL CONSTRAINT [DF__WorkflowT__Enabl__77CE17AF] DEFAULT (1),
  [SortOrder] [int] NOT NULL CONSTRAINT [DF__WorkflowT__SortO__78C23BE8] DEFAULT (0),
  [Description] [nvarchar](400) NOT NULL CONSTRAINT [DF_WorkflowTransition_Description] DEFAULT (N'')
)
ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SCore].[WorkflowTransition]')
GO
ALTER TABLE [SCore].[WorkflowTransition] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key on table [SCore].[WorkflowTransition]')
GO
ALTER TABLE [SCore].[WorkflowTransition] WITH NOCHECK
  ADD UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_WorkflowTransition_FromStatus] on table [SCore].[WorkflowTransition]')
GO
ALTER TABLE [SCore].[WorkflowTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_WorkflowTransition_FromStatus] FOREIGN KEY ([FromStatusID]) REFERENCES [SCore].[WorkflowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_WorkflowTransition_ToStatus] on table [SCore].[WorkflowTransition]')
GO
ALTER TABLE [SCore].[WorkflowTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_WorkflowTransition_ToStatus] FOREIGN KEY ([ToStatusID]) REFERENCES [SCore].[WorkflowStatus] ([ID])
GO

PRINT (N'Create foreign key [FK_WorkflowTransition_Workflow] on table [SCore].[WorkflowTransition]')
GO
ALTER TABLE [SCore].[WorkflowTransition] WITH NOCHECK
  ADD CONSTRAINT [FK_WorkflowTransition_Workflow] FOREIGN KEY ([WorkflowID]) REFERENCES [SCore].[Workflow] ([ID])
GO