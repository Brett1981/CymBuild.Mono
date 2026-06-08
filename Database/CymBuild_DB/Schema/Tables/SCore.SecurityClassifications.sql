PRINT (N'Create table [SCore].[SecurityClassifications]')
GO
CREATE TABLE [SCore].[SecurityClassifications] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_SecurityClassifications_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SecurityClassifications_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](50) NOT NULL,
  [Name] [nvarchar](100) NOT NULL,
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_SecurityClassifications_Description] DEFAULT (N''),
  [DisplayOrder] [int] NOT NULL CONSTRAINT [DF_SecurityClassifications_DisplayOrder] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SecurityClassifications] on table [SCore].[SecurityClassifications]')
GO
ALTER TABLE [SCore].[SecurityClassifications] WITH NOCHECK
  ADD CONSTRAINT [PK_SecurityClassifications] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_SecurityClassifications_Code_Active] on table [SCore].[SecurityClassifications]')
GO
CREATE UNIQUE INDEX [UX_SecurityClassifications_Code_Active]
  ON [SCore].[SecurityClassifications] ([Code])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [UX_SecurityClassifications_Guid] on table [SCore].[SecurityClassifications]')
GO
CREATE UNIQUE INDEX [UX_SecurityClassifications_Guid]
  ON [SCore].[SecurityClassifications] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO