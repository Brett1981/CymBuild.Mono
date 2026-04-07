CREATE TABLE [SSop].[EnquiryKeyDates] (
  [ID] [int] IDENTITY,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DC_EnquiryKeyDates_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DC_EnquiryKeyDates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [EnquiryId] [int] NOT NULL CONSTRAINT [DC_EnquiryKeyDates_EnquiryId] DEFAULT (-1),
  [Details] [varchar](500) NOT NULL DEFAULT (''),
  [DateTime] [datetime2] NULL,
  CONSTRAINT [PK_EnquiryKeyDates_ID] PRIMARY KEY CLUSTERED ([ID])
)
ON [PRIMARY]
GO

CREATE INDEX [IX_EnquiryKeyDatea_Enquiry]
  ON [SSop].[EnquiryKeyDates] ([EnquiryId], [RowStatus])
  WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

ALTER TABLE [SSop].[EnquiryKeyDates]
  ADD CONSTRAINT [FK_EnquiryKeyDates_EnquiryId] FOREIGN KEY ([EnquiryId]) REFERENCES [SSop].[Enquiries] ([ID]) ON DELETE CASCADE
GO

ALTER TABLE [SSop].[EnquiryKeyDates] WITH NOCHECK
  ADD CONSTRAINT [FK_EnquiryKeyDates_Guid] FOREIGN KEY ([Guid]) REFERENCES [SCore].[DataObjects] ([Guid])
GO

ALTER TABLE [SSop].[EnquiryKeyDates]
  NOCHECK CONSTRAINT [FK_EnquiryKeyDates_Guid]
GO

ALTER TABLE [SSop].[EnquiryKeyDates]
  ADD CONSTRAINT [FK_EnquiryKeyDates_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO