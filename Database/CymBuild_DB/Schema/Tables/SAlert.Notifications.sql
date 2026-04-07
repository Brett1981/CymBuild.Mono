CREATE TABLE [SAlert].[Notifications] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_Notifications_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_Notifications_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [Recipients] [nvarchar](max) NOT NULL CONSTRAINT [DF_Notifications_Recipients] DEFAULT (''),
  [Subject] [nvarchar](255) NOT NULL CONSTRAINT [DF_Notifications_Subject] DEFAULT (''),
  [Body] [nvarchar](max) NOT NULL CONSTRAINT [DF_Notifications_Body] DEFAULT (''),
  [BodyFormat] [nvarchar](20) NOT NULL CONSTRAINT [DF_Notifications_BodyFormat] DEFAULT (''),
  [Importance] [nvarchar](6) NOT NULL CONSTRAINT [DF_Notifications_Importance] DEFAULT (''),
  [DateTimeSent] [datetime2] NULL,
  CONSTRAINT [PK_Notifications] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE UNIQUE INDEX [IX_UQ_Notifications_Guid]
  ON [SAlert].[Notifications] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO