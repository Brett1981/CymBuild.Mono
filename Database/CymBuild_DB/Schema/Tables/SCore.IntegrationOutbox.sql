SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create table [SCore].[IntegrationOutbox]')
GO
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
  [JobGuidFromPayload] AS (case when isjson([PayloadJson])=(1) then TRY_CAST(json_value([PayloadJson],'$.jobGuid') AS [uniqueidentifier])  end) PERSISTED,
  [PublishingToken] [uniqueidentifier] NULL,
  [PublishingStartedOnUtc] [datetime2] NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_IntegrationOutbox] on table [SCore].[IntegrationOutbox]')
GO
ALTER TABLE [SCore].[IntegrationOutbox] WITH NOCHECK
  ADD CONSTRAINT [PK_IntegrationOutbox] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

SET QUOTED_IDENTIFIER ON
GO

PRINT (N'Create index [IX_IntegrationOutbox_PublishClaim] on table [SCore].[IntegrationOutbox]')
GO
CREATE INDEX [IX_IntegrationOutbox_PublishClaim]
  ON [SCore].[IntegrationOutbox] ([PublishedOnUtc], [PublishingToken], [CreatedOnUtc])
  INCLUDE ([ID], [Guid], [EventType], [PublishAttempts])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_IntegrationOutbox_Unpublished] on table [SCore].[IntegrationOutbox]')
GO
CREATE INDEX [IX_IntegrationOutbox_Unpublished]
  ON [SCore].[IntegrationOutbox] ([RowStatus], [PublishedOnUtc], [CreatedOnUtc])
  INCLUDE ([EventType], [Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO