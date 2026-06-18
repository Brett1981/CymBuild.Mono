PRINT (N'Create table [SCore].[SystemLog]')
GO
CREATE TABLE [SCore].[SystemLog] (
  [ID] [bigint] IDENTITY,
  [Datetime] [datetime2] NOT NULL CONSTRAINT [DF_Table_1_datetime] DEFAULT (getutcdate()),
  [UserID] [int] NOT NULL CONSTRAINT [DF_SystemLog_UserID] DEFAULT (-1),
  [Severity] [nvarchar](50) NOT NULL CONSTRAINT [DF_SystemLog_Severity] DEFAULT (''),
  [Message] [nvarchar](max) NOT NULL CONSTRAINT [DF_SystemLog_Message] DEFAULT (''),
  [InnerMessage] [nvarchar](max) NOT NULL CONSTRAINT [DF_SystemLog_InnerMessage] DEFAULT (''),
  [StackTrace] [nvarchar](max) NOT NULL CONSTRAINT [DF_SystemLog_StackTrace] DEFAULT (''),
  [ProcessGuid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_SystemLog_ProcessGuid] DEFAULT (newid()),
  [ThreadId] [bigint] NOT NULL CONSTRAINT [DF_SystemLog_ThreadId] DEFAULT (0)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SystemLog] on table [SCore].[SystemLog]')
GO
ALTER TABLE [SCore].[SystemLog] WITH NOCHECK
  ADD CONSTRAINT [PK_SystemLog] PRIMARY KEY CLUSTERED ([ID])
GO

PRINT (N'Create foreign key [FK_SystemLog_Identities] on table [SCore].[SystemLog]')
GO
ALTER TABLE [SCore].[SystemLog] WITH NOCHECK
  ADD CONSTRAINT [FK_SystemLog_Identities] FOREIGN KEY ([UserID]) REFERENCES [SCore].[Identities] ([ID])
GO