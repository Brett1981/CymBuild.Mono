/****** Object:  Table [SCore].[Identities]    Script Date: 02/02/2026 21:41:45 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[Identities](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[FullName] [nvarchar](250) NOT NULL,
	[EmailAddress] [nvarchar](150) NOT NULL,
	[UserGuid] [uniqueidentifier] NOT NULL,
	[JobTitle] [nvarchar](50) NOT NULL,
	[OriganisationalUnitId] [int] NOT NULL,
	[IsActive] [bit] NOT NULL,
	[ContactId] [int] NOT NULL,
	[BillableRate] [decimal](19, 2) NOT NULL,
	[LoweredEmailAddress]  AS (lower([EmailAddress])) PERSISTED,
	[Signature] [varbinary](max) NOT NULL,
 CONSTRAINT [PK_Identities] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Index [IX_Identities_List]    Script Date: 02/02/2026 21:41:45 ******/
CREATE NONCLUSTERED INDEX [IX_Identities_List] ON [SCore].[Identities]
(
	[IsActive] ASC,
	[RowStatus] ASC
)
INCLUDE([FullName],[Guid],[OriganisationalUnitId]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [IsActive]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [IX_Identities_LoweredEmailAddress]    Script Date: 02/02/2026 21:41:45 ******/
CREATE NONCLUSTERED INDEX [IX_Identities_LoweredEmailAddress] ON [SCore].[Identities]
(
	[LoweredEmailAddress] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Identities_Name]    Script Date: 02/02/2026 21:41:45 ******/
CREATE NONCLUSTERED INDEX [IX_Identities_Name] ON [SCore].[Identities]
(
	[FullName] ASC,
	[IsActive] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(254) AND [RowStatus]<>(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_Identities_EmailAddress]    Script Date: 02/02/2026 21:41:45 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Identities_EmailAddress] ON [SCore].[Identities]
(
	[EmailAddress] ASC
)
INCLUDE([Guid]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_Identities_Guid]    Script Date: 02/02/2026 21:41:45 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Identities_Guid] ON [SCore].[Identities]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Identities_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DEFAULT_Identities_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Identities_FullName]  DEFAULT (N'') FOR [FullName]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Tickets_EmailAddress]  DEFAULT (N'') FOR [EmailAddress]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Identities_UserGuid]  DEFAULT (newid()) FOR [UserGuid]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Identities_JobTitle]  DEFAULT ('') FOR [JobTitle]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Identities_OriganisationalUnitId]  DEFAULT ((-1)) FOR [OriganisationalUnitId]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Identities_IsActive]  DEFAULT ((0)) FOR [IsActive]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF__Identitie__Conta__6EE2037B]  DEFAULT ((-1)) FOR [ContactId]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Identities_BillableRate]  DEFAULT ((0)) FOR [BillableRate]
GO
ALTER TABLE [SCore].[Identities] ADD  CONSTRAINT [DF_Identities_Signature]  DEFAULT (0x) FOR [Signature]
GO
ALTER TABLE [SCore].[Identities]  WITH CHECK ADD  CONSTRAINT [FK_Identities_ContactId] FOREIGN KEY([ContactId])
REFERENCES [SCrm].[Contacts] ([ID])
GO
ALTER TABLE [SCore].[Identities] CHECK CONSTRAINT [FK_Identities_ContactId]
GO
ALTER TABLE [SCore].[Identities]  WITH NOCHECK ADD  CONSTRAINT [FK_Identities_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[Identities] CHECK CONSTRAINT [FK_Identities_DataObjects]
GO
ALTER TABLE [SCore].[Identities]  WITH CHECK ADD  CONSTRAINT [FK_Identities_OrganisationalUnits] FOREIGN KEY([OriganisationalUnitId])
REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO
ALTER TABLE [SCore].[Identities] CHECK CONSTRAINT [FK_Identities_OrganisationalUnits]
GO
ALTER TABLE [SCore].[Identities]  WITH CHECK ADD  CONSTRAINT [FK_Identities_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[Identities] CHECK CONSTRAINT [FK_Identities_RowStatus]
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Users mapped to their Entra ID''s' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'Identities'
GO
