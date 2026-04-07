CREATE TABLE [SCore].[RowStatus] (
  [ID] [tinyint] NOT NULL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_RowStatus_Name] DEFAULT (''),
  CONSTRAINT [PK_RowStatus] PRIMARY KEY CLUSTERED ([ID]) ON [METADATA]
)
ON [METADATA]
GO

CREATE UNIQUE INDEX [IX_UQ_RowStatus_Name]
  ON [SCore].[RowStatus] ([Name])
  WITH (FILLFACTOR = 100)
  ON [METADATA]
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'An Enum of possible RowStatus Values. Used to maintain the integrity of the RowStatus column on all tables. ', 'SCHEMA', N'SCore', 'TABLE', N'RowStatus'
GO