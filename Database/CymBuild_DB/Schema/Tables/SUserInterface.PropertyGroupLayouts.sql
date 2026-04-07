CREATE TABLE [SUserInterface].[PropertyGroupLayouts] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_PropertyGroupLayouts_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DEFAULT_PropertyGroupLayouts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Name] [nvarchar](50) NOT NULL CONSTRAINT [DF_PropertyGroupLayouts_Name] DEFAULT (''),
  CONSTRAINT [PK_PropertyGroupLayouts] PRIMARY KEY CLUSTERED ([ID]),
  CONSTRAINT [UQ__PropertyGroupLayouts_Guid] UNIQUE ([Guid])
)
ON [PRIMARY]
GO

ALTER TABLE [SUserInterface].[PropertyGroupLayouts]
  ADD CONSTRAINT [FK_PropertyGroupLayouts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'The options for how Property Groups are displayed e.g. Row or Column ', 'SCHEMA', N'SUserInterface', 'TABLE', N'PropertyGroupLayouts'
GO