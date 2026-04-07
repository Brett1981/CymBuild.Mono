CREATE TABLE [SCore].[LegacySystems] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_LegacySystems_Guid] DEFAULT (newid()),
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_LegacySystems_Name] DEFAULT (''),
  CONSTRAINT [PK_LegacySystems] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'LegacySystems', 'SCHEMA', N'SCore', 'TABLE', N'LegacySystems'
GO