CREATE TABLE [SJob].[Jobs_ShoreExt] (
  [ID] [int] NOT NULL CONSTRAINT [DF_ShoreJobs_Ext_ID] DEFAULT (-1),
  [IAID] [int] NOT NULL CONSTRAINT [DEFAULT_ShoreJobs_Ext_IAID] DEFAULT (-1),
  [Date] [datetime] NULL,
  [DateRec] [datetime] NULL,
  [FeeDate] [datetime] NULL,
  [AgreementSent] [datetime] NULL,
  [AgreementReceived] [datetime] NULL,
  [InvoiceText] [nvarchar](255) NOT NULL CONSTRAINT [DEFAULT_ShoreJobs_Ext_InvoiceText] DEFAULT (''),
  [OffList] [bit] NOT NULL CONSTRAINT [DEFAULT_ShoreJobs_Ext_OffList] DEFAULT (0),
  CONSTRAINT [PK_ShoreJobs_Ext] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
)
ON [PRIMARY]
GO

ALTER TABLE [SJob].[Jobs_ShoreExt]
  ADD CONSTRAINT [FK_ShoreJobs_Ext_Jobs] FOREIGN KEY ([ID]) REFERENCES [SJob].[Jobs] ([ID])
GO