/****** Object:  Table [SCore].[BankHolidaysUK]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[BankHolidaysUK](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Date] [datetime] NULL,
	[DayName] [varchar](20) NULL,
	[MonthName] [varchar](20) NULL,
	[YearInWords] [varchar](9) NULL,
	[FormattedDate] [varchar](25) NULL,
	[HolidayName] [varchar](50) NULL,
	[IsBankHoliday] [bit] NULL,
	[Region] [varchar](20) NULL,
	[FiscalQuarter] [tinyint] NULL,
	[FiscalYear] [smallint] NULL,
	[DayOfYear] [smallint] NULL,
	[WeekOfYear] [tinyint] NULL
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[DataObjectTransition]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[DataObjectTransition](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[StatusID] [int] NOT NULL,
	[OldStatusID] [int] NULL,
	[Comment] [nvarchar](max) NULL,
	[DateTimeUTC] [datetime2](7) NOT NULL,
	[CreatedByUserId] [int] NOT NULL,
	[SurveyorUserId] [int] NULL,
	[DataObjectGuid] [uniqueidentifier] NOT NULL,
	[IsImported] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SCore].[Identities]    Script Date: 02/02/2026 22:19:58 ******/
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
/****** Object:  Table [SCore].[IntegrationOutbox]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[IntegrationOutbox](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[CreatedOnUtc] [datetime2](7) NOT NULL,
	[EventType] [nvarchar](200) NOT NULL,
	[PayloadJson] [nvarchar](max) NOT NULL,
	[PublishedOnUtc] [datetime2](7) NULL,
	[PublishAttempts] [int] NOT NULL,
	[LastError] [nvarchar](max) NULL,
 CONSTRAINT [PK_IntegrationOutbox] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SCore].[LegacySystems]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[LegacySystems](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_LegacySystems] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[ObjectSecurity]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[ObjectSecurity](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[ObjectGuid] [uniqueidentifier] NOT NULL,
	[UserId] [int] NOT NULL,
	[GroupId] [int] NOT NULL,
	[CanRead] [bit] NOT NULL,
	[DenyRead] [bit] NOT NULL,
	[CanWrite] [bit] NOT NULL,
	[DenyWrite] [bit] NOT NULL,
 CONSTRAINT [PK_ObjectSecurity] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[ObjectSharePointFolder]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[ObjectSharePointFolder](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[ObjectGuid] [uniqueidentifier] NOT NULL,
	[SharepointSiteId] [int] NOT NULL,
	[FolderPath] [nvarchar](500) NOT NULL,
 CONSTRAINT [PK_ObjectSharePointFolder] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[OrganisationalUnits]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[OrganisationalUnits](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[ParentID] [int] NOT NULL,
	[AddressId] [int] NOT NULL,
	[ContactId] [int] NOT NULL,
	[OfficialAddressId] [int] NOT NULL,
	[OfficialContactId] [int] NOT NULL,
	[OrgNode] [hierarchyid] NULL,
	[DepartmentPrefix] [nvarchar](10) NOT NULL,
	[CostCentreCode] [nvarchar](50) NOT NULL,
	[DefaultSecurityGroupId] [int] NOT NULL,
	[OrgLevel]  AS ([OrgNode].[GetLevel]()),
	[IsCompany]  AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(1) then (1) else (0) end)) PERSISTED,
	[IsDivision]  AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(2) then (1) else (0) end)) PERSISTED,
	[IsBusinessUnit]  AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(3) then (1) else (0) end)) PERSISTED,
	[IsDepartment]  AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(4) then (1) else (0) end)) PERSISTED,
	[IsTeam]  AS (CONVERT([bit],case when [OrgNode].[GetLevel]()=(5) then (1) else (0) end)) PERSISTED,
	[QuoteThreshold] [decimal](19, 2) NULL,
 CONSTRAINT [PK_OrganisationalUnits] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[RecentItems]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[RecentItems](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Datetime] [datetime2](7) NOT NULL,
	[UserID] [int] NOT NULL,
	[EntityTypeID] [int] NOT NULL,
	[RecordGuid] [uniqueidentifier] NOT NULL,
	[Label] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_RecentItems] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[RecordHistory]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[RecordHistory](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[SchemaName] [nvarchar](250) NOT NULL,
	[TableName] [nvarchar](250) NOT NULL,
	[ColumnName] [nvarchar](250) NOT NULL,
	[RowID] [bigint] NOT NULL,
	[RowGuid] [uniqueidentifier] NOT NULL,
	[Datetime] [datetime] NOT NULL,
	[UserID] [int] NOT NULL,
	[SQLUser] [nvarchar](250) NOT NULL,
	[PreviousValue] [nvarchar](max) NOT NULL,
	[NewValue] [nvarchar](max) NOT NULL,
	[EntityPropertyID] [int] NOT NULL,
 CONSTRAINT [PK_RecordHistory] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SCore].[SharepointEntityStructure]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[SharepointEntityStructure](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[SharePointSiteID] [int] NOT NULL,
	[ParentStructureID] [int] NOT NULL,
	[EntityTypeID] [int] NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[UseLibraryPerSplit] [bit] NOT NULL,
	[PrimaryKeySplitInterval] [int] NOT NULL,
	[StartPrimaryKey] [bigint] NOT NULL,
	[EndPrimaryKey] [bigint] NOT NULL,
 CONSTRAINT [PK_SharepointEntityStructure] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[SharepointSites]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[SharepointSites](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[SiteIdentifier] [nvarchar](250) NOT NULL,
	[SiteUrl] [nvarchar](250) NOT NULL,
 CONSTRAINT [PK_SharepointSites] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[SynchronisationErrors]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[SynchronisationErrors](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[EntityPropertyID] [int] NOT NULL,
	[RecordID] [bigint] NOT NULL,
	[ProposedValue] [varbinary](max) NOT NULL,
	[ProposedByUserID] [int] NOT NULL,
	[ProposedDateTime] [datetime2](7) NOT NULL,
	[IsResolved] [bit] NOT NULL,
 CONSTRAINT [PK_SychronisationErrors] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SCore].[SystemLog]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[SystemLog](
	[ID] [bigint] IDENTITY(1,1) NOT NULL,
	[Datetime] [datetime2](7) NOT NULL,
	[UserID] [int] NOT NULL,
	[Severity] [nvarchar](50) NOT NULL,
	[Message] [nvarchar](max) NOT NULL,
	[InnerMessage] [nvarchar](max) NOT NULL,
	[StackTrace] [nvarchar](max) NOT NULL,
	[ProcessGuid] [uniqueidentifier] NOT NULL,
	[ThreadId] [bigint] NOT NULL,
 CONSTRAINT [PK_SystemLog] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SCore].[SystemUsageLog]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[SystemUsageLog](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[UserGuid] [uniqueidentifier] NOT NULL,
	[FeatureName] [nvarchar](255) NOT NULL,
	[Accessed] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[UserGroups]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[UserGroups](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[IdentityID] [int] NOT NULL,
	[GroupID] [int] NOT NULL,
 CONSTRAINT [PK_UserGroups] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[UserPreferences]    Script Date: 02/02/2026 22:19:58 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[UserPreferences](
	[ID] [int] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[SystemLanguageID] [int] NOT NULL,
	[WidgetLayout] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_UserPreferences] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ__UserPreferences_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Index [IX_DataObjectTransition_DataObjectGuid_IdDesc]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_DataObjectTransition_DataObjectGuid_IdDesc] ON [SCore].[DataObjectTransition]
(
	[DataObjectGuid] ASC,
	[ID] DESC
)
INCLUDE([RowStatus],[StatusID],[OldStatusID],[DateTimeUTC],[Guid]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_DataObjectTransition_DataObjectGuid_Status_Date]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_DataObjectTransition_DataObjectGuid_Status_Date] ON [SCore].[DataObjectTransition]
(
	[DataObjectGuid] ASC,
	[StatusID] ASC,
	[DateTimeUTC] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Identities_List]    Script Date: 02/02/2026 22:19:58 ******/
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
/****** Object:  Index [IX_Identities_LoweredEmailAddress]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_Identities_LoweredEmailAddress] ON [SCore].[Identities]
(
	[LoweredEmailAddress] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Identities_Name]    Script Date: 02/02/2026 22:19:58 ******/
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
/****** Object:  Index [IX_UQ_Identities_EmailAddress]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Identities_EmailAddress] ON [SCore].[Identities]
(
	[EmailAddress] ASC
)
INCLUDE([Guid]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_Identities_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Identities_Guid] ON [SCore].[Identities]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_IntegrationOutbox_Unpublished]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_IntegrationOutbox_Unpublished] ON [SCore].[IntegrationOutbox]
(
	[RowStatus] ASC,
	[PublishedOnUtc] ASC,
	[CreatedOnUtc] ASC
)
INCLUDE([EventType],[Guid]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_ObjectSecurity_CanRead]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_ObjectSecurity_CanRead] ON [SCore].[ObjectSecurity]
(
	[ObjectGuid] ASC,
	[CanRead] ASC,
	[RowStatus] ASC
)
INCLUDE([UserId],[GroupId]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_ObjectSecurity_DenyRead]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_ObjectSecurity_DenyRead] ON [SCore].[ObjectSecurity]
(
	[ObjectGuid] ASC,
	[DenyRead] ASC,
	[RowStatus] ASC
)
INCLUDE([UserId],[GroupId]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_ObjectSecurity_ObjectGuid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_ObjectSecurity_ObjectGuid] ON [SCore].[ObjectSecurity]
(
	[ObjectGuid] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_ObjectSecurity_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_ObjectSecurity_Guid] ON [SCore].[ObjectSecurity]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_ObjectSecurity_Setting]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_ObjectSecurity_Setting] ON [SCore].[ObjectSecurity]
(
	[ObjectGuid] ASC,
	[UserId] ASC,
	[GroupId] ASC,
	[RowStatus] ASC
)
INCLUDE([CanRead],[DenyRead],[CanWrite],[DenyWrite]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_ObjectSharePointFolder_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_ObjectSharePointFolder_Guid] ON [SCore].[ObjectSharePointFolder]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_ObjectSharePointFolder_ObjectGuid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_ObjectSharePointFolder_ObjectGuid] ON [SCore].[ObjectSharePointFolder]
(
	[ObjectGuid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_OrgUnits_OrgNode]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_OrgUnits_OrgNode] ON [SCore].[OrganisationalUnits]
(
	[OrgNode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_OrganisationalUnits_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_OrganisationalUnits_Guid] ON [SCore].[OrganisationalUnits]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_OrganisationalUnits_Name]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_OrganisationalUnits_Name] ON [SCore].[OrganisationalUnits]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ARITHABORT ON
SET CONCAT_NULL_YIELDS_NULL ON
SET QUOTED_IDENTIFIER ON
SET ANSI_NULLS ON
SET ANSI_PADDING ON
SET ANSI_WARNINGS ON
SET NUMERIC_ROUNDABORT OFF
GO
/****** Object:  Index [OrgUnitBFInd]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [OrgUnitBFInd] ON [SCore].[OrganisationalUnits]
(
	[OrgLevel] ASC,
	[OrgNode] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_RecentItems_Record]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_RecentItems_Record] ON [SCore].[RecentItems]
(
	[UserID] ASC,
	[RowStatus] ASC
)
INCLUDE([RowVersion],[Guid],[Datetime],[EntityTypeID],[RecordGuid],[Label]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_RecordHistory_Date]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_RecordHistory_Date] ON [SCore].[RecordHistory]
(
	[Datetime] ASC
)
INCLUDE([RowGuid]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_RecordHistory_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_RecordHistory_Guid] ON [SCore].[RecordHistory]
(
	[Guid] ASC
)WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_RecordHistory_RowGuid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_RecordHistory_RowGuid] ON [SCore].[RecordHistory]
(
	[RowGuid] ASC
)
INCLUDE([RowStatus],[Datetime]) WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_RecordHistory_RowStatus]    Script Date: 02/02/2026 22:19:58 ******/
CREATE NONCLUSTERED INDEX [IX_RecordHistory_RowStatus] ON [SCore].[RecordHistory]
(
	[RowStatus] ASC
)
INCLUDE([RowGuid],[Datetime]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_SharePointEntityStructure_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SharePointEntityStructure_Guid] ON [SCore].[SharepointEntityStructure]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_SharepointEntityStructure_Site_Parent_Name]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SharepointEntityStructure_Site_Parent_Name] ON [SCore].[SharepointEntityStructure]
(
	[SharePointSiteID] ASC,
	[ParentStructureID] ASC,
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_SharePointSites_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SharePointSites_Guid] ON [SCore].[SharepointSites]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_SharePointSites_SiteIdentifier]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SharePointSites_SiteIdentifier] ON [SCore].[SharepointSites]
(
	[SiteIdentifier] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_SychronisationErrors_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SychronisationErrors_Guid] ON [SCore].[SynchronisationErrors]
(
	[Guid] ASC
)
WHERE ([RowStatus]<>(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_UserGroups_Guid]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_UserGroups_Guid] ON [SCore].[UserGroups]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_UserGroups_Identity_Group]    Script Date: 02/02/2026 22:19:58 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_UserGroups_Identity_Group] ON [SCore].[UserGroups]
(
	[IdentityID] ASC,
	[GroupID] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
ALTER TABLE [SCore].[DataObjectTransition] ADD  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[DataObjectTransition] ADD  CONSTRAINT [DF_DataObjectTransition_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[DataObjectTransition] ADD  CONSTRAINT [DF_DataObjectTransition_StatusID]  DEFAULT ((-1)) FOR [StatusID]
GO
ALTER TABLE [SCore].[DataObjectTransition] ADD  DEFAULT (sysutcdatetime()) FOR [DateTimeUTC]
GO
ALTER TABLE [SCore].[DataObjectTransition] ADD  CONSTRAINT [DF_DataObjectTransition_CreatedByUserId]  DEFAULT ((-1)) FOR [CreatedByUserId]
GO
ALTER TABLE [SCore].[DataObjectTransition] ADD  CONSTRAINT [DF_DataObjectTransition_DataObjectGuid]  DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [DataObjectGuid]
GO
ALTER TABLE [SCore].[DataObjectTransition] ADD  CONSTRAINT [DF_WorkflowTransition_IsImported]  DEFAULT ((0)) FOR [IsImported]
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
ALTER TABLE [SCore].[IntegrationOutbox] ADD  CONSTRAINT [DF_IntegrationOutbox_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[IntegrationOutbox] ADD  CONSTRAINT [DF_IntegrationOutbox_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[IntegrationOutbox] ADD  CONSTRAINT [DF_IntegrationOutbox_CreatedOnUtc]  DEFAULT (sysutcdatetime()) FOR [CreatedOnUtc]
GO
ALTER TABLE [SCore].[IntegrationOutbox] ADD  CONSTRAINT [DF_IntegrationOutbox_EventType]  DEFAULT ('') FOR [EventType]
GO
ALTER TABLE [SCore].[IntegrationOutbox] ADD  CONSTRAINT [DF_IntegrationOutbox_PayloadJson]  DEFAULT ('') FOR [PayloadJson]
GO
ALTER TABLE [SCore].[IntegrationOutbox] ADD  CONSTRAINT [DF_IntegrationOutbox_PublishAttempts]  DEFAULT ((0)) FOR [PublishAttempts]
GO
ALTER TABLE [SCore].[LegacySystems] ADD  CONSTRAINT [DF_LegacySystems_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[LegacySystems] ADD  CONSTRAINT [DF_LegacySystems_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_RecordGuid]  DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [ObjectGuid]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_UserId]  DEFAULT ((-1)) FOR [UserId]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_GroupId]  DEFAULT ((-1)) FOR [GroupId]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_CanRead]  DEFAULT ((0)) FOR [CanRead]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_DenyRead]  DEFAULT ((0)) FOR [DenyRead]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_CanWrite]  DEFAULT ((0)) FOR [CanWrite]
GO
ALTER TABLE [SCore].[ObjectSecurity] ADD  CONSTRAINT [DF_ObjectSecurity_DenyWrite]  DEFAULT ((0)) FOR [DenyWrite]
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] ADD  CONSTRAINT [DF_ObjectSharePointFolder_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] ADD  CONSTRAINT [DF_ObjectSharePointFolder_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] ADD  CONSTRAINT [DF_ObjectSharePointFolder_RecordGuid]  DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [ObjectGuid]
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] ADD  CONSTRAINT [DF_ObjectSharePointFolder_SharepointSiteId]  DEFAULT ((-1)) FOR [SharepointSiteId]
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] ADD  CONSTRAINT [DF_ObjectSharePointFolder_FolderPath]  DEFAULT ('') FOR [FolderPath]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DEFAULT_OrganisationalUnits_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DEFAULT_OrganisationalUnits_ParentID]  DEFAULT ((-1)) FOR [ParentID]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_AddressId]  DEFAULT ((-1)) FOR [AddressId]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_ContactId]  DEFAULT ((-1)) FOR [ContactId]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_OfficialAddress]  DEFAULT ((-1)) FOR [OfficialAddressId]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_OfficialContactId]  DEFAULT ((-1)) FOR [OfficialContactId]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_DepartmentPrefix]  DEFAULT ('') FOR [DepartmentPrefix]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_CostCentreCode]  DEFAULT ('') FOR [CostCentreCode]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_DefaultSecurityGroupId]  DEFAULT ((-1)) FOR [DefaultSecurityGroupId]
GO
ALTER TABLE [SCore].[OrganisationalUnits] ADD  CONSTRAINT [DF_OrganisationalUnits_QuoteThreshold]  DEFAULT (NULL) FOR [QuoteThreshold]
GO
ALTER TABLE [SCore].[RecentItems] ADD  CONSTRAINT [DF_RecentItems_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[RecentItems] ADD  CONSTRAINT [DF_RecentItems_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[RecentItems] ADD  CONSTRAINT [DF_RecentItems_Datetime]  DEFAULT (getutcdate()) FOR [Datetime]
GO
ALTER TABLE [SCore].[RecentItems] ADD  CONSTRAINT [DF_RecentItems_UserID]  DEFAULT ((-1)) FOR [UserID]
GO
ALTER TABLE [SCore].[RecentItems] ADD  CONSTRAINT [DF_RecentItems_EntityTypeID]  DEFAULT ((-1)) FOR [EntityTypeID]
GO
ALTER TABLE [SCore].[RecentItems] ADD  CONSTRAINT [DF_RecentItems_RecordGuid]  DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [RecordGuid]
GO
ALTER TABLE [SCore].[RecentItems] ADD  CONSTRAINT [DF_RecentItems_Label]  DEFAULT ('') FOR [Label]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_SchemaName]  DEFAULT ('') FOR [SchemaName]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_Table]  DEFAULT ('') FOR [TableName]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_ColumnName]  DEFAULT ('') FOR [ColumnName]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_RowID]  DEFAULT ((-1)) FOR [RowID]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_RowGuid]  DEFAULT (newid()) FOR [RowGuid]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_Datetime]  DEFAULT (getutcdate()) FOR [Datetime]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_UserID]  DEFAULT ((-1)) FOR [UserID]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_SQLUser]  DEFAULT ('') FOR [SQLUser]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_PreviousValue]  DEFAULT ('') FOR [PreviousValue]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_NewValue]  DEFAULT ('') FOR [NewValue]
GO
ALTER TABLE [SCore].[RecordHistory] ADD  CONSTRAINT [DF_RecordHistory_EntityPropertyID]  DEFAULT ((-1)) FOR [EntityPropertyID]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DEFAULT_SharepointEntityStructure_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_SharePointSiteID]  DEFAULT ((-1)) FOR [SharePointSiteID]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_ParentStructureID]  DEFAULT ((-1)) FOR [ParentStructureID]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_EntityTypeID]  DEFAULT ((-1)) FOR [EntityTypeID]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_IsLibrary]  DEFAULT ((0)) FOR [UseLibraryPerSplit]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_PrimaryKeySplitInterval]  DEFAULT ((0)) FOR [PrimaryKeySplitInterval]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_StartPrimaryKey]  DEFAULT ((0)) FOR [StartPrimaryKey]
GO
ALTER TABLE [SCore].[SharepointEntityStructure] ADD  CONSTRAINT [DF_SharepointEntityStructure_EndPrimaryKey]  DEFAULT ((0)) FOR [EndPrimaryKey]
GO
ALTER TABLE [SCore].[SharepointSites] ADD  CONSTRAINT [DF_SharepointSites_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[SharepointSites] ADD  CONSTRAINT [DEFAULT_SharepointSites_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[SharepointSites] ADD  CONSTRAINT [DF_SharepointSites_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[SharepointSites] ADD  CONSTRAINT [DF_SharepointSites_SiteIdentifier]  DEFAULT ('') FOR [SiteIdentifier]
GO
ALTER TABLE [SCore].[SharepointSites] ADD  CONSTRAINT [DF_SharepointSites_SiteUrl]  DEFAULT ('') FOR [SiteUrl]
GO
ALTER TABLE [SCore].[SynchronisationErrors] ADD  CONSTRAINT [DF_SychronisationErrors_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[SynchronisationErrors] ADD  CONSTRAINT [DF_SychronisationErrors_Guid]  DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [Guid]
GO
ALTER TABLE [SCore].[SynchronisationErrors] ADD  CONSTRAINT [DF_SychronisationErrors_EntityPropertyID]  DEFAULT ((-1)) FOR [EntityPropertyID]
GO
ALTER TABLE [SCore].[SynchronisationErrors] ADD  CONSTRAINT [DF_SychronisationErrors_RecordID]  DEFAULT ((-1)) FOR [RecordID]
GO
ALTER TABLE [SCore].[SynchronisationErrors] ADD  CONSTRAINT [DF_SychronisationErrors_ProposedValue]  DEFAULT (0x00) FOR [ProposedValue]
GO
ALTER TABLE [SCore].[SynchronisationErrors] ADD  CONSTRAINT [DF_SychronisationErrors_ProposedByUserID]  DEFAULT ((-1)) FOR [ProposedByUserID]
GO
ALTER TABLE [SCore].[SynchronisationErrors] ADD  CONSTRAINT [DF_SychronisationErrors_ProposedDateTime]  DEFAULT (getutcdate()) FOR [ProposedDateTime]
GO
ALTER TABLE [SCore].[SynchronisationErrors] ADD  CONSTRAINT [DF_SychronisationErrors_IsResolved]  DEFAULT ((0)) FOR [IsResolved]
GO
ALTER TABLE [SCore].[SystemLog] ADD  CONSTRAINT [DF_Table_1_datetime]  DEFAULT (getutcdate()) FOR [Datetime]
GO
ALTER TABLE [SCore].[SystemLog] ADD  CONSTRAINT [DF_SystemLog_UserID]  DEFAULT ((-1)) FOR [UserID]
GO
ALTER TABLE [SCore].[SystemLog] ADD  CONSTRAINT [DF_SystemLog_Severity]  DEFAULT ('') FOR [Severity]
GO
ALTER TABLE [SCore].[SystemLog] ADD  CONSTRAINT [DF_SystemLog_Message]  DEFAULT ('') FOR [Message]
GO
ALTER TABLE [SCore].[SystemLog] ADD  CONSTRAINT [DF_SystemLog_InnerMessage]  DEFAULT ('') FOR [InnerMessage]
GO
ALTER TABLE [SCore].[SystemLog] ADD  CONSTRAINT [DF_SystemLog_StackTrace]  DEFAULT ('') FOR [StackTrace]
GO
ALTER TABLE [SCore].[SystemLog] ADD  CONSTRAINT [DF_SystemLog_ProcessGuid]  DEFAULT (newid()) FOR [ProcessGuid]
GO
ALTER TABLE [SCore].[SystemLog] ADD  CONSTRAINT [DF_SystemLog_ThreadId]  DEFAULT ((0)) FOR [ThreadId]
GO
ALTER TABLE [SCore].[SystemUsageLog] ADD  DEFAULT ('00000000-0000-0000-0000-000000000000') FOR [UserGuid]
GO
ALTER TABLE [SCore].[SystemUsageLog] ADD  DEFAULT ('') FOR [FeatureName]
GO
ALTER TABLE [SCore].[SystemUsageLog] ADD  DEFAULT (getutcdate()) FOR [Accessed]
GO
ALTER TABLE [SCore].[UserGroups] ADD  CONSTRAINT [DF_UserGroups_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[UserGroups] ADD  CONSTRAINT [DF_UserGroups_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[UserGroups] ADD  CONSTRAINT [DF_UserGroups_UserID]  DEFAULT ((-1)) FOR [IdentityID]
GO
ALTER TABLE [SCore].[UserGroups] ADD  CONSTRAINT [DF_UserGroups_GroupID]  DEFAULT ((-1)) FOR [GroupID]
GO
ALTER TABLE [SCore].[UserPreferences] ADD  CONSTRAINT [DF_UserPreferences_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[UserPreferences] ADD  CONSTRAINT [DF_MailerSettings_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[UserPreferences] ADD  CONSTRAINT [DF_UserPreferences_SystemLanguageId]  DEFAULT ((-1)) FOR [SystemLanguageID]
GO
ALTER TABLE [SCore].[UserPreferences] ADD  CONSTRAINT [DF_UserPreferences_WidgetLayout]  DEFAULT ('{"ItemStates": []}') FOR [WidgetLayout]
GO
ALTER TABLE [SCore].[DataObjectTransition]  WITH CHECK ADD  CONSTRAINT [FK_DataObjectTransition_CreatedBy] FOREIGN KEY([CreatedByUserId])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[DataObjectTransition] CHECK CONSTRAINT [FK_DataObjectTransition_CreatedBy]
GO
ALTER TABLE [SCore].[DataObjectTransition]  WITH NOCHECK ADD  CONSTRAINT [FK_DataObjectTransition_DataObjects] FOREIGN KEY([DataObjectGuid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[DataObjectTransition] CHECK CONSTRAINT [FK_DataObjectTransition_DataObjects]
GO
ALTER TABLE [SCore].[DataObjectTransition]  WITH CHECK ADD  CONSTRAINT [FK_DataObjectTransition_OldStatus] FOREIGN KEY([OldStatusID])
REFERENCES [SCore].[WorkflowStatus] ([ID])
GO
ALTER TABLE [SCore].[DataObjectTransition] CHECK CONSTRAINT [FK_DataObjectTransition_OldStatus]
GO
ALTER TABLE [SCore].[DataObjectTransition]  WITH CHECK ADD  CONSTRAINT [FK_DataObjectTransition_Status] FOREIGN KEY([StatusID])
REFERENCES [SCore].[WorkflowStatus] ([ID])
GO
ALTER TABLE [SCore].[DataObjectTransition] CHECK CONSTRAINT [FK_DataObjectTransition_Status]
GO
ALTER TABLE [SCore].[DataObjectTransition]  WITH CHECK ADD  CONSTRAINT [FK_DataObjectTransition_Surveyor] FOREIGN KEY([SurveyorUserId])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[DataObjectTransition] CHECK CONSTRAINT [FK_DataObjectTransition_Surveyor]
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
ALTER TABLE [SCore].[ObjectSecurity]  WITH NOCHECK ADD  CONSTRAINT [FK_ObjectSecurity_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[ObjectSecurity] CHECK CONSTRAINT [FK_ObjectSecurity_DataObjects]
GO
ALTER TABLE [SCore].[ObjectSecurity]  WITH CHECK ADD  CONSTRAINT [FK_ObjectSecurity_Goups] FOREIGN KEY([GroupId])
REFERENCES [SCore].[Groups] ([ID])
GO
ALTER TABLE [SCore].[ObjectSecurity] CHECK CONSTRAINT [FK_ObjectSecurity_Goups]
GO
ALTER TABLE [SCore].[ObjectSecurity]  WITH CHECK ADD  CONSTRAINT [FK_ObjectSecurity_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[ObjectSecurity] CHECK CONSTRAINT [FK_ObjectSecurity_RowStatus]
GO
ALTER TABLE [SCore].[ObjectSecurity]  WITH CHECK ADD  CONSTRAINT [FK_ObjectSecurity_Users] FOREIGN KEY([UserId])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[ObjectSecurity] CHECK CONSTRAINT [FK_ObjectSecurity_Users]
GO
ALTER TABLE [SCore].[ObjectSharePointFolder]  WITH NOCHECK ADD  CONSTRAINT [FK_ObjectSharePointFolder_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] CHECK CONSTRAINT [FK_ObjectSharePointFolder_DataObjects]
GO
ALTER TABLE [SCore].[ObjectSharePointFolder]  WITH CHECK ADD  CONSTRAINT [FK_ObjectSharePointFolder_SharepointSites] FOREIGN KEY([SharepointSiteId])
REFERENCES [SCore].[SharepointSites] ([ID])
GO
ALTER TABLE [SCore].[ObjectSharePointFolder] CHECK CONSTRAINT [FK_ObjectSharePointFolder_SharepointSites]
GO
ALTER TABLE [SCore].[OrganisationalUnits]  WITH NOCHECK ADD  CONSTRAINT [FK_OrganisationalUnits_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[OrganisationalUnits] CHECK CONSTRAINT [FK_OrganisationalUnits_DataObjects]
GO
ALTER TABLE [SCore].[OrganisationalUnits]  WITH CHECK ADD  CONSTRAINT [FK_OrganisationalUnits_Groups] FOREIGN KEY([DefaultSecurityGroupId])
REFERENCES [SCore].[Groups] ([ID])
GO
ALTER TABLE [SCore].[OrganisationalUnits] CHECK CONSTRAINT [FK_OrganisationalUnits_Groups]
GO
ALTER TABLE [SCore].[OrganisationalUnits]  WITH CHECK ADD  CONSTRAINT [FK_OrganisationalUnits_OrganisationalUnits] FOREIGN KEY([ParentID])
REFERENCES [SCore].[OrganisationalUnits] ([ID])
GO
ALTER TABLE [SCore].[OrganisationalUnits] CHECK CONSTRAINT [FK_OrganisationalUnits_OrganisationalUnits]
GO
ALTER TABLE [SCore].[RecentItems]  WITH NOCHECK ADD  CONSTRAINT [FK_RecentItems_DataObjects] FOREIGN KEY([RecordGuid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[RecentItems] CHECK CONSTRAINT [FK_RecentItems_DataObjects]
GO
ALTER TABLE [SCore].[RecentItems]  WITH NOCHECK ADD  CONSTRAINT [FK_RecentItems_EntityTypes] FOREIGN KEY([EntityTypeID])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SCore].[RecentItems] CHECK CONSTRAINT [FK_RecentItems_EntityTypes]
GO
ALTER TABLE [SCore].[RecentItems]  WITH CHECK ADD  CONSTRAINT [FK_RecentItems_Identities] FOREIGN KEY([UserID])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[RecentItems] CHECK CONSTRAINT [FK_RecentItems_Identities]
GO
ALTER TABLE [SCore].[RecordHistory]  WITH NOCHECK ADD  CONSTRAINT [FK_RecordHistory_DataObjects] FOREIGN KEY([RowGuid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[RecordHistory] NOCHECK CONSTRAINT [FK_RecordHistory_DataObjects]
GO
ALTER TABLE [SCore].[RecordHistory]  WITH NOCHECK ADD  CONSTRAINT [FK_RecordHistory_EntityPropertyID] FOREIGN KEY([EntityPropertyID])
REFERENCES [SCore].[EntityProperties] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[RecordHistory] CHECK CONSTRAINT [FK_RecordHistory_EntityPropertyID]
GO
ALTER TABLE [SCore].[RecordHistory]  WITH CHECK ADD  CONSTRAINT [FK_RecordHistory_Identities] FOREIGN KEY([UserID])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[RecordHistory] CHECK CONSTRAINT [FK_RecordHistory_Identities]
GO
ALTER TABLE [SCore].[SharepointEntityStructure]  WITH NOCHECK ADD  CONSTRAINT [FK_SharepointEntityStructure_EntityTypes] FOREIGN KEY([EntityTypeID])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SCore].[SharepointEntityStructure] CHECK CONSTRAINT [FK_SharepointEntityStructure_EntityTypes]
GO
ALTER TABLE [SCore].[SharepointEntityStructure]  WITH CHECK ADD  CONSTRAINT [FK_SharepointEntityStructure_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[SharepointEntityStructure] CHECK CONSTRAINT [FK_SharepointEntityStructure_RowStatus]
GO
ALTER TABLE [SCore].[SharepointEntityStructure]  WITH CHECK ADD  CONSTRAINT [FK_SharepointEntityStructure_SharepointEntityStructure] FOREIGN KEY([ParentStructureID])
REFERENCES [SCore].[SharepointEntityStructure] ([ID])
GO
ALTER TABLE [SCore].[SharepointEntityStructure] CHECK CONSTRAINT [FK_SharepointEntityStructure_SharepointEntityStructure]
GO
ALTER TABLE [SCore].[SharepointEntityStructure]  WITH CHECK ADD  CONSTRAINT [FK_SharepointEntityStructure_SharepointSites] FOREIGN KEY([SharePointSiteID])
REFERENCES [SCore].[SharepointSites] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[SharepointEntityStructure] CHECK CONSTRAINT [FK_SharepointEntityStructure_SharepointSites]
GO
ALTER TABLE [SCore].[SharepointSites]  WITH CHECK ADD  CONSTRAINT [FK_SharepointSites_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[SharepointSites] CHECK CONSTRAINT [FK_SharepointSites_RowStatus]
GO
ALTER TABLE [SCore].[SynchronisationErrors]  WITH NOCHECK ADD  CONSTRAINT [FK_SychronisationErrors_EntityPropertyID] FOREIGN KEY([EntityPropertyID])
REFERENCES [SCore].[EntityProperties] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[SynchronisationErrors] CHECK CONSTRAINT [FK_SychronisationErrors_EntityPropertyID]
GO
ALTER TABLE [SCore].[SynchronisationErrors]  WITH CHECK ADD  CONSTRAINT [FK_SychronisationErrors_ProposedUserID] FOREIGN KEY([ProposedByUserID])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[SynchronisationErrors] CHECK CONSTRAINT [FK_SychronisationErrors_ProposedUserID]
GO
ALTER TABLE [SCore].[SynchronisationErrors]  WITH CHECK ADD  CONSTRAINT [FK_SynchronisationErrors_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[SynchronisationErrors] CHECK CONSTRAINT [FK_SynchronisationErrors_RowStatus]
GO
ALTER TABLE [SCore].[SystemLog]  WITH CHECK ADD  CONSTRAINT [FK_SystemLog_Identities] FOREIGN KEY([UserID])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[SystemLog] CHECK CONSTRAINT [FK_SystemLog_Identities]
GO
ALTER TABLE [SCore].[UserGroups]  WITH NOCHECK ADD  CONSTRAINT [FK_UserGroups_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[UserGroups] CHECK CONSTRAINT [FK_UserGroups_DataObjects]
GO
ALTER TABLE [SCore].[UserGroups]  WITH CHECK ADD  CONSTRAINT [FK_UserGroups_Groups] FOREIGN KEY([GroupID])
REFERENCES [SCore].[Groups] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[UserGroups] CHECK CONSTRAINT [FK_UserGroups_Groups]
GO
ALTER TABLE [SCore].[UserGroups]  WITH CHECK ADD  CONSTRAINT [FK_UserGroups_Identities] FOREIGN KEY([IdentityID])
REFERENCES [SCore].[Identities] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[UserGroups] CHECK CONSTRAINT [FK_UserGroups_Identities]
GO
ALTER TABLE [SCore].[UserGroups]  WITH CHECK ADD  CONSTRAINT [FK_UserGroups_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[UserGroups] CHECK CONSTRAINT [FK_UserGroups_RowStatus]
GO
ALTER TABLE [SCore].[UserPreferences]  WITH CHECK ADD  CONSTRAINT [FK_UserPreferences_Identities] FOREIGN KEY([ID])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[UserPreferences] CHECK CONSTRAINT [FK_UserPreferences_Identities]
GO
ALTER TABLE [SCore].[UserPreferences]  WITH CHECK ADD  CONSTRAINT [FK_UserPreferences_Languages] FOREIGN KEY([SystemLanguageID])
REFERENCES [SCore].[Languages] ([ID])
GO
ALTER TABLE [SCore].[UserPreferences] CHECK CONSTRAINT [FK_UserPreferences_Languages]
GO
ALTER TABLE [SCore].[UserPreferences]  WITH CHECK ADD  CONSTRAINT [FK_UserPreferences_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[UserPreferences] CHECK CONSTRAINT [FK_UserPreferences_RowStatus]
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Users mapped to their Entra ID''s' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'Identities'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'LegacySystems' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'LegacySystems'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Security records for all rows both meta data and user data. ' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'ObjectSecurity'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'A log of which items each user has opened. ' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'RecentItems'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'An audit of all changes made to user data. ' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'RecordHistory'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The mapping between Users and their Groups' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'UserGroups'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'User settable preferences, e.g. their default system language. ' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'UserPreferences'
GO
