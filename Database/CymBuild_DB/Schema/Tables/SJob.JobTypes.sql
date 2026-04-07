CREATE TABLE [SJob].[JobTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_JobTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_JobTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_JobTypes_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DF_JobTypes_IsActive] DEFAULT (1),
  [SequenceID] [int] NOT NULL CONSTRAINT [DF_JobTypes_SequenceID] DEFAULT (-1),
  [UseTimeSheets] [bit] NOT NULL CONSTRAINT [DF_JobTypes_UseTimeSheets] DEFAULT (0),
  [UsePlanChecks] [bit] NOT NULL CONSTRAINT [DF_JobTypes_UsePlanChecks] DEFAULT (0),
  [OrganisationalUnitID] [int] NOT NULL CONSTRAINT [DF_JobTypes_OrganisationalUnitID] DEFAULT (-1),
  CONSTRAINT [PK_JobTypes] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobTypes_Guid]
  ON [SJob].[JobTypes] ([Guid])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_JobTypes_Name]
  ON [SJob].[JobTypes] ([Name])
  WITH (FILLFACTOR = 100)
  ON [PRIMARY]
GO

ALTER TABLE [SJob].[JobTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_JobTypes_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SJob].[JobTypes]
  NOCHECK CONSTRAINT [FK_JobTypes_DataObjects]
GO

ALTER TABLE [SJob].[JobTypes]
  ADD CONSTRAINT [FK_JobTypes_OrganisationalUnits] FOREIGN KEY ([OrganisationalUnitID]) REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO

ALTER TABLE [SJob].[JobTypes]
  ADD CONSTRAINT [FK_JobTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

ALTER TABLE [SJob].[JobTypes]
  ADD CONSTRAINT [FK_JobTypes_SequenceTable] FOREIGN KEY ([SequenceID]) REFERENCES [SCore].[SequenceTable] ([ID])
GO