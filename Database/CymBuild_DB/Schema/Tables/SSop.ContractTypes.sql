CREATE TABLE [SSop].[ContractTypes] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_ContractTypes_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_ContractTypes_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](20) NOT NULL CONSTRAINT [DC_ContractTypes_Code] DEFAULT (''),
  [Name] [nvarchar](250) NOT NULL CONSTRAINT [DC_ContractTypes_Name] DEFAULT (''),
  [IsActive] [bit] NOT NULL CONSTRAINT [DC_ContractTypes_IsActive] DEFAULT (0),
  CONSTRAINT [PK_ContractTypes_ID] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_MilestoneTypes_Code]
  ON [SSop].[ContractTypes] ([Code])
  ON [PRIMARY]
GO

ALTER TABLE [SSop].[ContractTypes] WITH NOCHECK
  ADD CONSTRAINT [FK_ContractTypes_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[ContractTypes]
  NOCHECK CONSTRAINT [FK_ContractTypes_Guid]
GO

ALTER TABLE [SSop].[ContractTypes]
  ADD CONSTRAINT [FK_ContractTypes_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', 'Type of contract e.g. Fee Matrix, Framework Agreement', 'SCHEMA', N'SSop', 'TABLE', N'ContractTypes'
GO