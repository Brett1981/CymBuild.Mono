PRINT (N'Create table [SCrm].[ContactDetails]')
GO
CREATE TABLE [SCrm].[ContactDetails] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ContactDetails_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ContactDetails_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [ContactID] [int] NOT NULL CONSTRAINT [DF_ContactDetails_ContactID] DEFAULT (-1),
  [ContactDetailTypeID] [smallint] NOT NULL CONSTRAINT [DF_ContactDetails_ContactDetailTypeID] DEFAULT (-1),
  [Name] [nvarchar](100) NOT NULL CONSTRAINT [DF_ContactDetails_Name] DEFAULT (N''),
  [Value] [nvarchar](250) NOT NULL CONSTRAINT [DF_ContactDetails_Value] DEFAULT (N''),
  [IsDefault] [bit] NOT NULL CONSTRAINT [DF_ContactDetails_IsDefault] DEFAULT (0)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_ContactDetails] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [PK_ContactDetails] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create index [IX_UQ_ContactDetails_ContactID_Name] on table [SCrm].[ContactDetails]')
GO
CREATE UNIQUE INDEX [IX_UQ_ContactDetails_ContactID_Name]
  ON [SCrm].[ContactDetails] ([ContactID], [Name])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_ContactDetails_Guid] on table [SCrm].[ContactDetails]')
GO
CREATE UNIQUE INDEX [IX_UQ_ContactDetails_Guid]
  ON [SCrm].[ContactDetails] ([Guid])
  WITH (FILLFACTOR = 90)
  ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_ContactDetails_ContactDetailTypes] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetails_ContactDetailTypes] FOREIGN KEY ([ContactDetailTypeID]) REFERENCES [SCrm].[ContactDetailTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_ContactDetails_Contacts] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetails_Contacts] FOREIGN KEY ([ContactID]) REFERENCES [SCrm].[Contacts] ([ID]) ON DELETE CASCADE
GO

PRINT (N'Create foreign key [FK_ContactDetails_DataObjects] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetails_DataObjects] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

PRINT (N'Disable foreign key [FK_ContactDetails_DataObjects] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails]
  NOCHECK CONSTRAINT [FK_ContactDetails_DataObjects]
GO

PRINT (N'Create foreign key [FK_ContactDetails_RowStatus] on table [SCrm].[ContactDetails]')
GO
ALTER TABLE [SCrm].[ContactDetails] WITH NOCHECK
  ADD CONSTRAINT [FK_ContactDetails_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO