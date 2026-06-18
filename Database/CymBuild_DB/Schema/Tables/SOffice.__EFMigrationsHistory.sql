PRINT (N'Create table [SOffice].[__EFMigrationsHistory]')
GO
CREATE TABLE [SOffice].[__EFMigrationsHistory] (
  [MigrationId] [nvarchar](150) NOT NULL,
  [ProductVersion] [nvarchar](32) NOT NULL
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK___EFMigrationsHistory] on table [SOffice].[__EFMigrationsHistory]')
GO
ALTER TABLE [SOffice].[__EFMigrationsHistory] WITH NOCHECK
  ADD CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY CLUSTERED ([MigrationId])
GO