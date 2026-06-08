PRINT (N'Create table [SCore].[DataClassifications]')
GO
CREATE TABLE [SCore].[DataClassifications] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_DataClassifications_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_DataClassifications_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Code] [nvarchar](50) NOT NULL,
  [Name] [nvarchar](100) NOT NULL,
  [Description] [nvarchar](500) NOT NULL CONSTRAINT [DF_DataClassifications_Description] DEFAULT (N''),
  [DisplayOrder] [int] NOT NULL CONSTRAINT [DF_DataClassifications_DisplayOrder] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_DataClassifications] on table [SCore].[DataClassifications]')
GO
ALTER TABLE [SCore].[DataClassifications] WITH NOCHECK
  ADD CONSTRAINT [PK_DataClassifications] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [UX_DataClassifications_Code_Active] on table [SCore].[DataClassifications]')
GO
CREATE UNIQUE INDEX [UX_DataClassifications_Code_Active]
  ON [SCore].[DataClassifications] ([Code])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [UX_DataClassifications_Guid] on table [SCore].[DataClassifications]')
GO
CREATE UNIQUE INDEX [UX_DataClassifications_Guid]
  ON [SCore].[DataClassifications] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO