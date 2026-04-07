CREATE TABLE [SSop].[ProjectKeyDates] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ProjectKeyDates_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ProjectKeyDates_RowStatus] DEFAULT (0),
  [RowVersion] [timestamp],
  [ProjectID] [int] NOT NULL CONSTRAINT [DF_ProjectKeyDates_ProjectID] DEFAULT (-1),
  [Detail] [nvarchar](500) NOT NULL CONSTRAINT [DF_ProjectKeyDates_Detail] DEFAULT (''),
  [DateTime] [datetime2] NULL
)
ON [PRIMARY]
GO