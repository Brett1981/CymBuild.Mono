CREATE TABLE [SFin].[SageExternalAllocations]
(
    [ID]                       BIGINT IDENTITY(1,1) NOT NULL,
    [RowStatus]                TINYINT NOT NULL,
    [RowVersion]               ROWVERSION NOT NULL,
    [Guid]                     UNIQUEIDENTIFIER ROWGUIDCOL NOT NULL,

    [SourceExternalTransactionID] BIGINT NOT NULL,
    [TargetExternalTransactionID] BIGINT NOT NULL,

    [AllocatedAmount]          DECIMAL(18,2) NOT NULL DEFAULT ((0)),
    [AllocationDate]           DATE NULL,

    [MatchedSourceTransactionID] BIGINT NOT NULL DEFAULT (-1),
    [MatchedTargetTransactionID] BIGINT NOT NULL DEFAULT (-1),

    [SourceHash]               NVARCHAR(128) NOT NULL DEFAULT (N''),
    [LastSeenOnUtc]            DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),
    [RawPayloadJson]           NVARCHAR(MAX) NULL,

    [CreatedByUserID]          INT NOT NULL DEFAULT (-1),
    [CreatedDateTimeUTC]       DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedByUserID]          INT NOT NULL DEFAULT (-1),
    [UpdatedDateTimeUTC]       DATETIME2(7) NOT NULL DEFAULT (GETUTCDATE()),

    CONSTRAINT [PK_SageExternalAllocations] PRIMARY KEY CLUSTERED ([ID] ASC),
    CONSTRAINT [UQ_SageExternalAllocations_Guid] UNIQUE NONCLUSTERED ([Guid])
);
GO