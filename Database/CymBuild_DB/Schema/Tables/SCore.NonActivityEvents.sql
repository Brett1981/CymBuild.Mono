PRINT (N'Create table [SCore].[NonActivityEvents]')
GO
CREATE TABLE [SCore].[NonActivityEvents] (
  [ID] [int] IDENTITY,
  [StartTime] [datetime] NULL,
  [EndTime] [datetime] NULL,
  [MemberIdentityId] [int] NOT NULL CONSTRAINT [DF_NonActivityEvents_MemberId] DEFAULT (-1),
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF__NonActivit__Guid__75709C27] DEFAULT (newid()),
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF__NonActivi__RowSt__7664C060] DEFAULT (1),
  [RowVersion] [timestamp],
  [TeamGroupId] [int] NOT NULL CONSTRAINT [DF_NonActivityEvents_TeamId] DEFAULT (-1),
  [AbsenceTypeID] [int] NOT NULL CONSTRAINT [DF_NonActivityEvents_AbsenceTypeID] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create foreign key [FK_NonActivityEvents_AbsenceTypes] on table [SCore].[NonActivityEvents]')
GO
ALTER TABLE [SCore].[NonActivityEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_NonActivityEvents_AbsenceTypes] FOREIGN KEY ([AbsenceTypeID]) REFERENCES [SCore].[NonActivityTypes] ([ID])
GO

PRINT (N'Create foreign key [FK_NonActivityEvents_Groups] on table [SCore].[NonActivityEvents]')
GO
ALTER TABLE [SCore].[NonActivityEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_NonActivityEvents_Groups] FOREIGN KEY ([TeamGroupId]) REFERENCES [SCore].[Groups] ([ID])
GO

PRINT (N'Create foreign key [FK_NonActivityEvents_Identities] on table [SCore].[NonActivityEvents]')
GO
ALTER TABLE [SCore].[NonActivityEvents] WITH NOCHECK
  ADD CONSTRAINT [FK_NonActivityEvents_Identities] FOREIGN KEY ([MemberIdentityId]) REFERENCES [SCore].[Identities] ([ID])
GO