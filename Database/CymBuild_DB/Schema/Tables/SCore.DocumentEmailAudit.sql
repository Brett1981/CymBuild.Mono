PRINT (N'Create table [SCore].[DocumentEmailAudit]')
GO
CREATE TABLE [SCore].[DocumentEmailAudit] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_DocumentEmailAudit_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_DocumentEmailAudit_Guid] DEFAULT (newid()),
  [RecordGuid] [uniqueidentifier] NOT NULL,
  [EntityTypeId] [int] NOT NULL,
  [CreatedByUserId] [int] NOT NULL,
  [CreatedDateTimeUTC] [datetime2] NOT NULL CONSTRAINT [DF_DocumentEmailAudit_CreatedDateTimeUTC] DEFAULT (sysutcdatetime()),
  [DraftMessageId] [nvarchar](512) NOT NULL,
  [DraftWebLink] [nvarchar](2000) NULL,
  [Subject] [nvarchar](500) NOT NULL,
  [BodyPreview] [nvarchar](1000) NULL,
  [RecordNumber] [nvarchar](250) NULL,
  [RecordDescription] [nvarchar](1000) NULL,
  [RecordLocation] [nvarchar](1000) NULL,
  [AttachmentCount] [int] NOT NULL,
  [AttachmentJson] [nvarchar](max) NULL
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_DocumentEmailAudit] on table [SCore].[DocumentEmailAudit]')
GO
ALTER TABLE [SCore].[DocumentEmailAudit] WITH NOCHECK
  ADD CONSTRAINT [PK_DocumentEmailAudit] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO