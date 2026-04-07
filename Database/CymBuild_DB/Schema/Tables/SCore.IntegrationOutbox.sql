CREATE TABLE [SCore].[IntegrationOutbox] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_IntegrationOutbox_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_IntegrationOutbox_Guid] DEFAULT (newid()),
  [CreatedOnUtc] [datetime2] NOT NULL CONSTRAINT [DF_IntegrationOutbox_CreatedOnUtc] DEFAULT (sysutcdatetime()),
  [EventType] [nvarchar](200) NOT NULL CONSTRAINT [DF_IntegrationOutbox_EventType] DEFAULT (''),
  [PayloadJson] [nvarchar](max) NOT NULL CONSTRAINT [DF_IntegrationOutbox_PayloadJson] DEFAULT (''),
  [PublishedOnUtc] [datetime2] NULL,
  [PublishAttempts] [int] NOT NULL CONSTRAINT [DF_IntegrationOutbox_PublishAttempts] DEFAULT (0),
  [LastError] [nvarchar](max) NULL,
  CONSTRAINT [PK_IntegrationOutbox] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

CREATE INDEX [IX_IntegrationOutbox_Unpublished]
  ON [SCore].[IntegrationOutbox] ([RowStatus], [PublishedOnUtc], [CreatedOnUtc])
  INCLUDE ([EventType], [Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO