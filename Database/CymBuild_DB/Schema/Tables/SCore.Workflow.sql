PRINT (N'Create table [SCore].[Workflow]')
GO
CREATE TABLE [SCore].[Workflow] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF__Workflow__RowSta__688BD41F] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NULL CONSTRAINT [DF_Workflow_Guid] DEFAULT (newid()),
  [OrganisationalUnitId] [int] NOT NULL CONSTRAINT [DF_DataObjectTransition_OrganisationalUnitId] DEFAULT (-1),
  [EntityTypeID] [int] NOT NULL CONSTRAINT [DF_DataObjectTransition_EntityTypeID] DEFAULT (-1),
  [EntityHoBTID] [int] NULL CONSTRAINT [DF_Workflow_EntityHoBTID] DEFAULT (-1),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_Workflow_Name] DEFAULT (''),
  [Description] [nvarchar](400) NULL,
  [Enabled] [bit] NOT NULL CONSTRAINT [DF__Workflow__Enable__6D50893C] DEFAULT (1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key on table [SCore].[Workflow]')
GO
ALTER TABLE [SCore].[Workflow] WITH NOCHECK
  ADD PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key on table [SCore].[Workflow]')
GO
ALTER TABLE [SCore].[Workflow] WITH NOCHECK
  ADD UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create foreign key [FK_Workflow_EntityHoBTs] on table [SCore].[Workflow]')
GO
ALTER TABLE [SCore].[Workflow] WITH NOCHECK
  ADD CONSTRAINT [FK_Workflow_EntityHoBTs] FOREIGN KEY ([EntityHoBTID]) REFERENCES [SCore].[EntityHobts] ([ID])
GO

PRINT (N'Create foreign key [FK_Workflow_EntityTypes] on table [SCore].[Workflow]')
GO
ALTER TABLE [SCore].[Workflow] WITH NOCHECK
  ADD CONSTRAINT [FK_Workflow_EntityTypes] FOREIGN KEY ([EntityTypeID]) REFERENCES [SCore].[EntityTypes] ([ID])
GO