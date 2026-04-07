CREATE TABLE [SSop].[ScheduleOfClientInformation] (
  [ID] [bigint] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_ScheduleOfClientInformation_Guid] DEFAULT (newid()),
  [RowVersion] [timestamp],
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_ScheduleOfClientInformation_RowStatus] DEFAULT (0),
  [EnquiryId] [int] NOT NULL CONSTRAINT [DF_ScheduleOfClientInformation_EnquiryId] DEFAULT (-1),
  [Item] [nvarchar](200) NOT NULL CONSTRAINT [DF_ScheduleOfClientInformation_Item] DEFAULT ('')
)
ON [PRIMARY]
GO

ALTER TABLE [SSop].[ScheduleOfClientInformation]
  ADD CONSTRAINT [FK_ScheduleOfClientInformation_Enquiries] FOREIGN KEY ([EnquiryId]) REFERENCES [SSop].[Enquiries] ([ID])
GO

EXEC sys.sp_addextendedproperty N'MS_Description', N'Schedule of Information recieved from the client that allowed us to prepare this fee proposal. ', 'SCHEMA', N'SSop', 'TABLE', N'ScheduleOfClientInformation'
GO