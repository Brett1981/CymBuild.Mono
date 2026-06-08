PRINT (N'Create table [SFin].[SageExternalAllocations]')
GO
CREATE TABLE [SFin].[SageExternalAllocations] (
  [ID] [bigint] IDENTITY,
  [RowStatus] [tinyint] NOT NULL,
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL ROWGUIDCOL,
  [SourceExternalTransactionID] [bigint] NOT NULL,
  [TargetExternalTransactionID] [bigint] NOT NULL,
  [AllocatedAmount] [decimal](18, 2) NOT NULL DEFAULT (0),
  [AllocationDate] [date] NULL,
  [MatchedSourceTransactionID] [bigint] NOT NULL DEFAULT (-1),
  [MatchedTargetTransactionID] [bigint] NOT NULL DEFAULT (-1),
  [SourceHash] [nvarchar](128) NOT NULL DEFAULT (N''),
  [LastSeenOnUtc] [datetime2] NOT NULL DEFAULT (getutcdate()),
  [RawPayloadJson] [nvarchar](max) NULL,
  [CreatedByUserID] [int] NOT NULL DEFAULT (-1),
  [CreatedDateTimeUTC] [datetime2] NOT NULL DEFAULT (getutcdate()),
  [UpdatedByUserID] [int] NOT NULL DEFAULT (-1),
  [UpdatedDateTimeUTC] [datetime2] NOT NULL DEFAULT (getutcdate())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SageExternalAllocations] on table [SFin].[SageExternalAllocations]')
GO
ALTER TABLE [SFin].[SageExternalAllocations] WITH NOCHECK
  ADD CONSTRAINT [PK_SageExternalAllocations] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique key [UQ_SageExternalAllocations_Guid] on table [SFin].[SageExternalAllocations]')
GO
ALTER TABLE [SFin].[SageExternalAllocations] WITH NOCHECK
  ADD CONSTRAINT [UQ_SageExternalAllocations_Guid] UNIQUE ([Guid]) WITH (FILLFACTOR = 80)
GO