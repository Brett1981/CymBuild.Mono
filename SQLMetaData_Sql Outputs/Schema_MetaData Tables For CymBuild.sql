/****** Object:  Table [SCore].[EntityDataTypes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityDataTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[QuoteValue] [bit] NOT NULL,
 CONSTRAINT [PK_EntityDataTypes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[EntityHobts]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityHobts](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[SchemaName] [nvarchar](250) NOT NULL,
	[ObjectName] [nvarchar](250) NOT NULL,
	[EntityTypeID] [int] NOT NULL,
	[ObjectType] [char](1) NOT NULL,
	[IsMainHoBT] [bit] NOT NULL,
	[IsReadOnlyOffline] [bit] NOT NULL,
 CONSTRAINT [PK_EntityHoBTs] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[EntityProperties]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityProperties](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[LanguageLabelID] [int] NOT NULL,
	[EntityHoBTID] [int] NOT NULL,
	[EntityDataTypeID] [int] NOT NULL,
	[IsReadOnly] [bit] NOT NULL,
	[IsImmutable] [bit] NOT NULL,
	[IsUppercase] [bit] NOT NULL,
	[IsHidden] [bit] NOT NULL,
	[IsCompulsory] [bit] NOT NULL,
	[MaxLength] [int] NOT NULL,
	[Precision] [int] NOT NULL,
	[Scale] [int] NOT NULL,
	[DoNotTrackChanges] [bit] NOT NULL,
	[EntityPropertyGroupID] [int] NOT NULL,
	[SortOrder] [smallint] NOT NULL,
	[GroupSortOrder] [smallint] NOT NULL,
	[IsObjectLabel] [bit] NOT NULL,
	[DropDownListDefinitionID] [int] NOT NULL,
	[IsParentRelationship] [bit] NOT NULL,
	[IsLongitude] [bit] NOT NULL,
	[IsLatitude] [bit] NOT NULL,
	[IsIncludedInformation] [bit] NOT NULL,
	[FixedDefaultValue] [nvarchar](50) NOT NULL,
	[SqlDefaultValueStatement] [nvarchar](4000) NOT NULL,
	[AllowBulkChange] [bit] NOT NULL,
	[IsVirtual] [bit] NOT NULL,
	[ShowOnMobile] [bit] NOT NULL,
	[IsAlwaysVisibleInGroup] [bit] NOT NULL,
	[IsAlwaysVisibleInGroup_Mobile] [bit] NOT NULL,
 CONSTRAINT [PK_EntityProperties] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[EntityPropertyActions]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityPropertyActions](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[EntityPropertyID] [int] NOT NULL,
	[Statement] [nvarchar](4000) NOT NULL,
 CONSTRAINT [PK_EntityPropertyActions] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[EntityPropertyDependants]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityPropertyDependants](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[ParentEntityPropertyID] [int] NOT NULL,
	[DependantPropertyID] [int] NOT NULL,
 CONSTRAINT [PK_EntityPropertyDependants] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[EntityPropertyGroups]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityPropertyGroups](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[IsHidden] [bit] NOT NULL,
	[SortOrder] [smallint] NOT NULL,
	[LanguageLabelID] [int] NOT NULL,
	[EntityTypeID] [int] NOT NULL,
	[PropertyGroupLayoutID] [int] NOT NULL,
	[ShowOnMobile] [bit] NOT NULL,
	[IsCollapsable] [bit] NOT NULL,
	[IsDefaultCollapsed] [bit] NOT NULL,
	[IsDefaultCollapsed_Mobile] [bit] NOT NULL,
 CONSTRAINT [PK_EntityPropertyGroups] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[EntityQueries]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityQueries](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[Statement] [nvarchar](max) NOT NULL,
	[EntityTypeID] [int] NOT NULL,
	[EntityHoBTID] [int] NOT NULL,
	[IsDefaultCreate] [bit] NOT NULL,
	[IsDefaultRead] [bit] NOT NULL,
	[IsDefaultUpdate] [bit] NOT NULL,
	[IsDefaultDelete] [bit] NOT NULL,
	[IsScalarExecute] [bit] NOT NULL,
	[IsDefaultValidation] [bit] NOT NULL,
	[UsesProcessGuid] [bit] NOT NULL,
	[IsDefaultDataPills] [bit] NOT NULL,
	[IsProgressData] [bit] NOT NULL,
	[IsMergeDocumentQuery] [bit] NOT NULL,
	[SchemaName] [nvarchar](255) NOT NULL,
	[ObjectName] [nvarchar](255) NOT NULL,
	[IsManualStatement] [bit] NOT NULL,
 CONSTRAINT [PK_EntityQueries] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SCore].[EntityQueryParameters]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityQueryParameters](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[EntityQueryID] [int] NOT NULL,
	[EntityDataTypeID] [int] NOT NULL,
	[MappedEntityPropertyID] [int] NOT NULL,
	[DefaultValue] [nvarchar](100) NOT NULL,
	[IsInput] [bit] NOT NULL,
	[IsOutput] [bit] NOT NULL,
	[IsReturnColumn] [bit] NOT NULL,
 CONSTRAINT [PK_EntityQueryParameters] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[EntityTypes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[EntityTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[IsReadOnlyOffline] [bit] NOT NULL,
	[IsRequiredSystemData] [bit] NOT NULL,
	[HasDocuments] [bit] NOT NULL,
	[LanguageLabelID] [int] NOT NULL,
	[DoNotTrackChanges] [bit] NOT NULL,
	[IsRootEntity] [bit] NOT NULL,
	[DetailPageUrl] [nvarchar](250) NOT NULL,
	[IconId] [int] NOT NULL,
	[IsMetaData] [bit] NOT NULL,
 CONSTRAINT [PK_EntityTypes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[Groups]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[Groups](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[DirectoryId] [nvarchar](100) NOT NULL,
	[Code] [nvarchar](30) NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[Source] [nvarchar](250) NOT NULL,
 CONSTRAINT [PK_Groups] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[LanguageLabels]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[LanguageLabels](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
 CONSTRAINT [PK_LanguageLabels] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[LanguageLabelTranslations]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[LanguageLabelTranslations](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Text] [nvarchar](250) NOT NULL,
	[TextPlural] [nvarchar](250) NOT NULL,
	[LanguageLabelID] [int] NOT NULL,
	[LanguageID] [int] NOT NULL,
	[HelpText] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_LanguageLabelTranslations] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SCore].[Languages]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[Languages](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[Locale] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_Languages] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[MergeDocumentItemIncludes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[MergeDocumentItemIncludes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[MergeDocumentItemId] [int] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[SourceDocumentEntityPropertyId] [int] NOT NULL,
	[SourceSharePointItemEntityPropertyId] [int] NOT NULL,
	[IncludedMergeDocumentId] [int] NOT NULL,
 CONSTRAINT [PK_MergeDocumentItemIncludes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[MergeDocumentItems]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[MergeDocumentItems](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[MergeDocumentId] [int] NOT NULL,
	[MergeDocumentItemTypeId] [smallint] NOT NULL,
	[BookmarkName] [nvarchar](50) NOT NULL,
	[EntityTypeId] [int] NOT NULL,
	[SubFolderPath] [nvarchar](200) NOT NULL,
	[ImageColumns] [int] NOT NULL,
 CONSTRAINT [PK_MergeDocumentItems] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[MergeDocumentItemTypes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[MergeDocumentItemTypes](
	[ID] [smallint] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[IsImageType] [bit] NOT NULL,
 CONSTRAINT [PK_MergeDocumentItemTypes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[MergeDocuments]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[MergeDocuments](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](250) NOT NULL,
	[FilenameTemplate] [nvarchar](250) NOT NULL,
	[EntityTypeId] [int] NOT NULL,
	[DocumentId] [nvarchar](500) NOT NULL,
	[LinkedEntityTypeId] [int] NOT NULL,
	[SharepointSiteId] [int] NOT NULL,
	[AllowPDFOutputOnly] [bit] NOT NULL,
	[ProduceOneOutputPerRow] [bit] NOT NULL,
	[AllowExcelOutputOnly] [bit] NOT NULL,
 CONSTRAINT [PK_MergeDocuments] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ__MergeDocuments_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[MergeDocumentTables]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[MergeDocumentTables](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[MergeDocumentId] [int] NOT NULL,
	[TableName] [nvarchar](50) NOT NULL,
	[LinkedEntityTypeId] [int] NOT NULL,
 CONSTRAINT [PK_MergeDocumentTables] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ__MergeDocumentTables_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[NonActivityEvents]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[NonActivityEvents](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[StartTime] [datetime] NULL,
	[EndTime] [datetime] NULL,
	[MemberIdentityId] [int] NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[TeamGroupId] [int] NOT NULL,
	[AbsenceTypeID] [int] NOT NULL
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[NonActivityTypes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[NonActivityTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[RowStatus]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[RowStatus](
	[ID] [tinyint] NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_RowStatus] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[Sectors]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[Sectors](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Code] [nvarchar](20) NOT NULL,
	[Name] [nvarchar](150) NOT NULL,
	[Description] [nvarchar](max) NOT NULL,
 CONSTRAINT [PK_Sectors] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SCore].[SequenceTable]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[SequenceTable](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[SysName] [nvarchar](50) NOT NULL,
	[FriendlyName] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_SequenceTable] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[SharepointSites]    Script Date: 02/02/2026 21:13:09 ******/
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
/****** Object:  Table [SCore].[System]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[System](
	[ID] [int] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[StandardPriceListID] [int] NOT NULL,
 CONSTRAINT [PK_System] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[Versioning]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[Versioning](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Version] [nvarchar](10) NOT NULL,
	[Description] [nvarchar](100) NOT NULL,
	[IsCurrent] [bit] NOT NULL,
 CONSTRAINT [PK_Versioning] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SCore].[Workflow]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[Workflow](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[OrganisationalUnitId] [int] NOT NULL,
	[EntityTypeID] [int] NOT NULL,
	[EntityHoBTID] [int] NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](400) NULL,
	[Enabled] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[WorkflowStatus]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[WorkflowStatus](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[OrganisationalUnitId] [int] NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[Description] [nvarchar](400) NOT NULL,
	[ShowInEnquiries] [bit] NOT NULL,
	[ShowInQuotes] [bit] NOT NULL,
	[ShowInJobs] [bit] NOT NULL,
	[Enabled] [bit] NOT NULL,
	[IsPredefined] [bit] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[Colour] [nvarchar](7) NOT NULL,
	[Icon] [nvarchar](50) NULL,
	[SendNotification] [bit] NOT NULL,
	[IsCompleteStatus] [bit] NOT NULL,
	[IsCustomerWaitingStatus] [bit] NOT NULL,
	[RequiresUsersAction] [bit] NOT NULL,
	[IsActiveStatus] [bit] NOT NULL,
	[AuthorisationNeeded] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[WorkflowStatusNotificationGroups]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[WorkflowStatusNotificationGroups](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] NOT NULL,
	[WorkflowID] [int] NOT NULL,
	[WorkflowStatusGuid] [uniqueidentifier] NOT NULL,
	[GroupID] [int] NOT NULL,
	[CanAction] [bit] NOT NULL,
 CONSTRAINT [PK_WorkflowStatusNotificationGroups] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SCore].[WorkflowTransition]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[WorkflowTransition](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[WorkflowID] [int] NOT NULL,
	[FromStatusID] [int] NOT NULL,
	[ToStatusID] [int] NOT NULL,
	[IsFinal] [bit] NOT NULL,
	[Enabled] [bit] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[Description] [nvarchar](400) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SUserInterface].[ActionMenuItems]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[ActionMenuItems](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[LanguageLabelId] [int] NOT NULL,
	[IconCss] [nvarchar](100) NOT NULL,
	[Type] [nvarchar](1) NOT NULL,
	[EntityTypeId] [int] NOT NULL,
	[EntityQueryId] [int] NOT NULL,
	[SortOrder] [int] NOT NULL,
	[RedirectToTargetGuid] [bit] NOT NULL,
 CONSTRAINT [PK_ActionMenuItems] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SUserInterface].[DropDownListDefinitions]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[DropDownListDefinitions](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Code] [nvarchar](20) NOT NULL,
	[NameColumn] [nvarchar](254) NOT NULL,
	[ValueColumn] [nvarchar](254) NOT NULL,
	[SqlQuery] [nvarchar](max) NOT NULL,
	[DefaultSortColumnName] [nvarchar](254) NOT NULL,
	[IsDefaultColumn] [nvarchar](254) NOT NULL,
	[DetailPageUrl] [nvarchar](250) NOT NULL,
	[IsDetailWindowed] [bit] NOT NULL,
	[EntityTypeId] [int] NOT NULL,
	[InformationPageUrl] [nvarchar](250) NOT NULL,
	[GroupColumn] [nvarchar](254) NOT NULL,
	[ColourHexColumn] [nvarchar](7) NOT NULL,
	[ExternalSearchPageUrl] [nvarchar](250) NOT NULL,
 CONSTRAINT [PK_DropDownListDefinitions] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SUserInterface].[GridDefinitions]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[GridDefinitions](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Code] [nvarchar](30) NOT NULL,
	[PageUri] [nvarchar](250) NOT NULL,
	[TabName] [nvarchar](100) NOT NULL,
	[ShowAsTiles] [bit] NOT NULL,
	[LanguageLabelId] [int] NOT NULL,
 CONSTRAINT [PK_GridDefinitions] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[GridViewActions]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[GridViewActions](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[GridViewDefinitionId] [int] NOT NULL,
	[LanguageLabelId] [int] NOT NULL,
	[EntityQueryId] [int] NOT NULL,
 CONSTRAINT [PK_GridViewActions] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[GridViewColumnDefinitions]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[GridViewColumnDefinitions](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](100) NOT NULL,
	[ColumnOrder] [int] NOT NULL,
	[GridViewDefinitionId] [int] NOT NULL,
	[IsPrimaryKey] [bit] NOT NULL,
	[IsHidden] [bit] NOT NULL,
	[IsFiltered] [bit] NOT NULL,
	[IsCombo] [bit] NOT NULL,
	[IsLongitude] [bit] NOT NULL,
	[IsLatitude] [bit] NOT NULL,
	[DisplayFormat] [nvarchar](50) NOT NULL,
	[Width] [nvarchar](10) NOT NULL,
	[LanguageLabelId] [int] NOT NULL,
	[TopHeaderCategory] [nvarchar](50) NOT NULL,
	[TopHeaderCategoryOrder] [int] NOT NULL,
 CONSTRAINT [PK_GridViewColumnDefinitions] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[GridViewDefinitions]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[GridViewDefinitions](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Code] [nvarchar](20) NOT NULL,
	[GridDefinitionId] [int] NOT NULL,
	[DetailPageUri] [nvarchar](250) NOT NULL,
	[SqlQuery] [nvarchar](max) NOT NULL,
	[DefaultSortColumnName] [nvarchar](250) NOT NULL,
	[SecurableCode] [nvarchar](20) NOT NULL,
	[DisplayOrder] [int] NOT NULL,
	[DisplayGroupName] [nvarchar](50) NOT NULL,
	[MetricSqlQuery] [nvarchar](max) NOT NULL,
	[ShowMetric] [bit] NOT NULL,
	[IsDetailWindowed] [bit] NOT NULL,
	[EntityTypeID] [int] NOT NULL,
	[MetricTypeID] [int] NOT NULL,
	[MetricMin] [int] NOT NULL,
	[MetricMax] [int] NOT NULL,
	[MetricMinorUnit] [int] NOT NULL,
	[MetricMajorUnit] [int] NOT NULL,
	[MetricStartAngle] [int] NOT NULL,
	[MetricEndAngle] [int] NOT NULL,
	[MetricReversed] [bit] NOT NULL,
	[MetricRange1Min] [decimal](18, 0) NOT NULL,
	[MetricRange1Max] [decimal](18, 0) NOT NULL,
	[MetricRange1ColourHex] [nvarchar](10) NOT NULL,
	[MetricRange2Min] [decimal](18, 0) NOT NULL,
	[MetricRange2Max] [decimal](18, 0) NOT NULL,
	[MetricRange2ColourHex] [nvarchar](10) NOT NULL,
	[IsDefaultSortDescending] [bit] NOT NULL,
	[AllowNew] [bit] NOT NULL,
	[AllowExcelExport] [bit] NOT NULL,
	[AllowPdfExport] [bit] NOT NULL,
	[AllowCsvExport] [bit] NOT NULL,
	[LanguageLabelId] [int] NOT NULL,
	[DrawerIconId] [int] NOT NULL,
	[GridViewTypeId] [int] NOT NULL,
	[AllowBulkChange] [bit] NOT NULL,
	[ShowOnMobile] [bit] NOT NULL,
	[TreeListFirstOrderBy] [nvarchar](100) NOT NULL,
	[TreeListSecondOrderBy] [nvarchar](100) NOT NULL,
	[TreeListThirdOrderBy] [nvarchar](100) NOT NULL,
	[TreeListOrderBy] [nvarchar](100) NOT NULL,
	[TreeListGroupBy] [nvarchar](100) NOT NULL,
	[ShowOnDashboard] [bit] NOT NULL,
	[FilteredListCreatedOnColumn] [nvarchar](100) NOT NULL,
	[FilteredListRedStatusIndicatorTxt] [nvarchar](100) NOT NULL,
	[FilteredListOrangeStatusIndicatorTxt] [nvarchar](100) NOT NULL,
	[FilteredListGreenStatusIndicatorTxt] [nvarchar](100) NOT NULL,
	[FilteredListGroupBy] [nvarchar](100) NOT NULL,
 CONSTRAINT [PK_GridViewDefinitions] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA] TEXTIMAGE_ON [PRIMARY]
GO
/****** Object:  Table [SUserInterface].[GridViewTypes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[GridViewTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_GridViewTypes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[GridViewWidgetQueries]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[GridViewWidgetQueries](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[GridViewDefinitionId] [int] NOT NULL,
	[EntityQueryId] [int] NOT NULL,
	[WidgetTypeId] [smallint] NOT NULL,
	[LanguageLabelID] [int] NOT NULL,
 CONSTRAINT [PK_GridViewWidgetQueries] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[Icons]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[Icons](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_Icons_ID] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA],
 CONSTRAINT [UK_Icons_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[MainMenuItems]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[MainMenuItems](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[LanguageLabelId] [int] NOT NULL,
	[IconId] [int] NOT NULL,
	[NavigationUrl] [nvarchar](500) NOT NULL,
	[SortOrder] [int] NOT NULL,
 CONSTRAINT [PK_MainMenuItems] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[MetricTypes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[MetricTypes](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_MetricTypes] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[PropertyGroupLayouts]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[PropertyGroupLayouts](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_PropertyGroupLayouts] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY],
 CONSTRAINT [UQ__PropertyGroupLayouts_Guid] UNIQUE NONCLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
/****** Object:  Table [SUserInterface].[WidgetDashboards]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[WidgetDashboards](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
	[ParentEntityTypeId] [int] NOT NULL,
 CONSTRAINT [PK_WidgetDashboards] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[WidgetDashboardWidgetTypes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[WidgetDashboardWidgetTypes](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[WidgetDashboardId] [int] NOT NULL,
	[WidgetTypeId] [smallint] NOT NULL,
 CONSTRAINT [PK_WidgetDashboardWidgetTypes] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Table [SUserInterface].[WidgetTypes]    Script Date: 02/02/2026 21:13:09 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SUserInterface].[WidgetTypes](
	[Id] [smallint] IDENTITY(1,1) NOT NULL,
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[Name] [nvarchar](50) NOT NULL,
 CONSTRAINT [PK_WidgetTypes] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityDataTypes_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityDataTypes_Guid] ON [SCore].[EntityDataTypes]
(
	[Guid] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_EntityDataTypes_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityDataTypes_Name] ON [SCore].[EntityDataTypes]
(
	[Name] ASC
)
WHERE ([RowStatus]<>(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_EntityHobts_EntityTypeID]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_EntityHobts_EntityTypeID] ON [SCore].[EntityHobts]
(
	[EntityTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_EntityTypeHobts]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_EntityTypeHobts] ON [SCore].[EntityHobts]
(
	[EntityTypeID] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityHoBTs_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityHoBTs_Guid] ON [SCore].[EntityHobts]
(
	[Guid] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_EntityHobts_SchemaName_ObjectName]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityHobts_SchemaName_ObjectName] ON [SCore].[EntityHobts]
(
	[SchemaName] ASC,
	[ObjectName] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_HobtProperties]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_HobtProperties] ON [SCore].[EntityProperties]
(
	[EntityHoBTID] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityProperties_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityProperties_Guid] ON [SCore].[EntityProperties]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_EntityProperties_Hobt_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityProperties_Hobt_Name] ON [SCore].[EntityProperties]
(
	[EntityHoBTID] ASC,
	[Name] ASC,
	[RowStatus] ASC
)
INCLUDE([Guid]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_EntityPropertyActions_EntityProperty]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_EntityPropertyActions_EntityProperty] ON [SCore].[EntityPropertyActions]
(
	[EntityPropertyID] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityPropertyActions_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityPropertyActions_Guid] ON [SCore].[EntityPropertyActions]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityPropertyDependants_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityPropertyDependants_Guid] ON [SCore].[EntityPropertyDependants]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_EntityPropertyDependants_Parent_Dependant]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityPropertyDependants_Parent_Dependant] ON [SCore].[EntityPropertyDependants]
(
	[ParentEntityPropertyID] ASC,
	[DependantPropertyID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_EntityPropertyGroups_EntityTypeID_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityPropertyGroups_EntityTypeID_Name] ON [SCore].[EntityPropertyGroups]
(
	[Name] ASC,
	[EntityTypeID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_EntityPropertyGroups_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityPropertyGroups_Guid] ON [SCore].[EntityPropertyGroups]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_EntityQueries_EntityTypeID]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_EntityQueries_EntityTypeID] ON [SCore].[EntityQueries]
(
	[EntityTypeID] ASC,
	[RowStatus] ASC
)
INCLUDE([RowVersion],[Guid],[Name],[EntityHoBTID],[IsDefaultCreate],[IsDefaultRead],[IsDefaultUpdate],[IsDefaultDelete],[IsProgressData],[Statement],[IsScalarExecute],[IsDefaultValidation],[IsDefaultDataPills]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityQueries_EntityHobtID_IsDefaultCreate]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueries_EntityHobtID_IsDefaultCreate] ON [SCore].[EntityQueries]
(
	[EntityTypeID] ASC,
	[EntityHoBTID] ASC,
	[IsDefaultCreate] ASC,
	[RowStatus] ASC
)
WHERE ([IsDefaultCreate]=(1) AND [RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityQueries_EntityHobtID_IsDefaultDelete]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueries_EntityHobtID_IsDefaultDelete] ON [SCore].[EntityQueries]
(
	[EntityTypeID] ASC,
	[EntityHoBTID] ASC,
	[IsDefaultDelete] ASC,
	[RowStatus] ASC
)
WHERE ([IsDefaultDelete]=(1) AND [RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityQueries_EntityHobtID_IsDefaultUpdate]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueries_EntityHobtID_IsDefaultUpdate] ON [SCore].[EntityQueries]
(
	[EntityTypeID] ASC,
	[EntityHoBTID] ASC,
	[IsDefaultUpdate] ASC,
	[RowStatus] ASC
)
WHERE ([IsDefaultUpdate]=(1) AND [RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityQueries_EntityHobtID_IsDefaultValidation]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueries_EntityHobtID_IsDefaultValidation] ON [SCore].[EntityQueries]
(
	[EntityHoBTID] ASC,
	[IsDefaultValidation] ASC,
	[EntityTypeID] ASC
)
WHERE ([IsDefaultValidation]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityQueries_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueries_Guid] ON [SCore].[EntityQueries]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_EntityQueries_Name_EntityTypeID]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueries_Name_EntityTypeID] ON [SCore].[EntityQueries]
(
	[Name] ASC,
	[EntityTypeID] ASC,
	[EntityHoBTID] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_EntityQueryParameters_Settings]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_EntityQueryParameters_Settings] ON [SCore].[EntityQueryParameters]
(
	[EntityQueryID] ASC,
	[RowStatus] ASC
)
INCLUDE([RowVersion],[Guid],[Name],[EntityDataTypeID],[MappedEntityPropertyID]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityQueryParameters_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueryParameters_Guid] ON [SCore].[EntityQueryParameters]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_EntityQueryParameters_Name_EntityQueryID]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueryParameters_Name_EntityQueryID] ON [SCore].[EntityQueryParameters]
(
	[Name] ASC,
	[EntityQueryID] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_EntityTypes_Get]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_EntityTypes_Get] ON [SCore].[EntityTypes]
(
	[Guid] ASC
)
INCLUDE([RowStatus],[RowVersion],[Name],[HasDocuments],[LanguageLabelID],[IconId]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_EntityTypes_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityTypes_Guid] ON [SCore].[EntityTypes]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_EntityTypes_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityTypes_Name] ON [SCore].[EntityTypes]
(
	[Name] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_DirectoryID]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_DirectoryID] ON [SCore].[Groups]
(
	[DirectoryId] ASC
)
WHERE ([DirectoryId]<>N'')
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_Groups_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Groups_Guid] ON [SCore].[Groups]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_Uq_Groups_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_Uq_Groups_Name] ON [SCore].[Groups]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_LanguageLabels_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_LanguageLabels_Guid] ON [SCore].[LanguageLabels]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_LanguageLabels_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_LanguageLabels_Name] ON [SCore].[LanguageLabels]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_LanguageLabelTranslations_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_LanguageLabelTranslations_Guid] ON [SCore].[LanguageLabelTranslations]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_LanguageLabelTranslations_Label_Language]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_LanguageLabelTranslations_Label_Language] ON [SCore].[LanguageLabelTranslations]
(
	[LanguageID] ASC,
	[LanguageLabelID] ASC,
	[RowStatus] ASC
)
INCLUDE([Text],[TextPlural]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_Languages_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Languages_Guid] ON [SCore].[Languages]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_Languages_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_Languages_Name] ON [SCore].[Languages]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_MergeDocumentItemIncludes_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MergeDocumentItemIncludes_Guid] ON [SCore].[MergeDocumentItemIncludes]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_MergeDocumentItems_BookmarkName]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MergeDocumentItems_BookmarkName] ON [SCore].[MergeDocumentItems]
(
	[MergeDocumentId] ASC,
	[BookmarkName] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_MergeDocumentItems_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MergeDocumentItems_Guid] ON [SCore].[MergeDocumentItems]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_MergeDocumentItemsTypes_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MergeDocumentItemsTypes_Name] ON [SCore].[MergeDocumentItemTypes]
(
	[Name] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_MergeDocumentItemTypes_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MergeDocumentItemTypes_Guid] ON [SCore].[MergeDocumentItemTypes]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_RowStatus_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_RowStatus_Name] ON [SCore].[RowStatus]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_SequenceTable_FriendlyName]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SequenceTable_FriendlyName] ON [SCore].[SequenceTable]
(
	[FriendlyName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_SequenceTable_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SequenceTable_Guid] ON [SCore].[SequenceTable]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_SequenceTable_SysName]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SequenceTable_SysName] ON [SCore].[SequenceTable]
(
	[SysName] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_SharePointSites_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SharePointSites_Guid] ON [SCore].[SharepointSites]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_SharePointSites_SiteIdentifier]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SharePointSites_SiteIdentifier] ON [SCore].[SharepointSites]
(
	[SiteIdentifier] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_Versioning_IsCurrent]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_Versioning_IsCurrent] ON [SCore].[Versioning]
(
	[IsCurrent] ASC
)
WHERE ([IsCurrent]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_WorkflowStatus_Id_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_WorkflowStatus_Id_Guid] ON [SCore].[WorkflowStatus]
(
	[ID] ASC
)
INCLUDE([Guid]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_WorkflowStatusNotificationGroups_Lookup]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_WorkflowStatusNotificationGroups_Lookup] ON [SCore].[WorkflowStatusNotificationGroups]
(
	[RowStatus] ASC,
	[WorkflowID] ASC,
	[WorkflowStatusGuid] ASC
)
INCLUDE([GroupID],[CanAction]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_WorkflowStatusNotificationGroups_Workflow_Status]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_WorkflowStatusNotificationGroups_Workflow_Status] ON [SCore].[WorkflowStatusNotificationGroups]
(
	[WorkflowID] ASC,
	[WorkflowStatusGuid] ASC
)
INCLUDE([GroupID],[CanAction]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [UX_WorkflowStatusNotificationGroups_Workflow_Status_Group]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [UX_WorkflowStatusNotificationGroups_Workflow_Status_Group] ON [SCore].[WorkflowStatusNotificationGroups]
(
	[WorkflowID] ASC,
	[WorkflowStatusGuid] ASC,
	[GroupID] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_ActionMenuItems_EntityTypeId]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_ActionMenuItems_EntityTypeId] ON [SUserInterface].[ActionMenuItems]
(
	[EntityTypeId] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_ActionMenuItems_Gud]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_ActionMenuItems_Gud] ON [SUserInterface].[ActionMenuItems]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_DropDownListDefinition_Settings]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_DropDownListDefinition_Settings] ON [SUserInterface].[DropDownListDefinitions]
(
	[Guid] ASC,
	[RowStatus] ASC
)
INCLUDE([NameColumn],[ValueColumn],[SqlQuery],[Code],[DefaultSortColumnName],[GroupColumn]) WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_DropDownListDefinition_Code]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_DropDownListDefinition_Code] ON [SUserInterface].[DropDownListDefinitions]
(
	[Code] ASC,
	[RowStatus] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_DropDownListDefinition_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_DropDownListDefinition_Guid] ON [SUserInterface].[DropDownListDefinitions]
(
	[Guid] ASC,
	[RowStatus] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_GridDefinition_Code]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridDefinition_Code] ON [SUserInterface].[GridDefinitions]
(
	[Code] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_GridDefinition_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridDefinition_Guid] ON [SUserInterface].[GridDefinitions]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_GridViewActions_Unique]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridViewActions_Unique] ON [SUserInterface].[GridViewActions]
(
	[GridViewDefinitionId] ASC,
	[EntityQueryId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_GridViewColumnDefinitions_GridView]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_GridViewColumnDefinitions_GridView] ON [SUserInterface].[GridViewColumnDefinitions]
(
	[GridViewDefinitionId] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_GridViewColumnDefinition_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridViewColumnDefinition_Guid] ON [SUserInterface].[GridViewColumnDefinitions]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_GridViewColumndefinition_IsPrimaryKey]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridViewColumndefinition_IsPrimaryKey] ON [SUserInterface].[GridViewColumnDefinitions]
(
	[GridViewDefinitionId] ASC,
	[IsPrimaryKey] ASC
)
WHERE ([IsPrimaryKey]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_GridViewDefinitions_Metrics]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_GridViewDefinitions_Metrics] ON [SUserInterface].[GridViewDefinitions]
(
	[ShowMetric] ASC,
	[RowStatus] ASC
)
INCLUDE([DisplayGroupName],[DisplayOrder],[GridDefinitionId],[Guid],[MetricReversed],[MetricSqlQuery],[MetricStartAngle],[MetricTypeID],[MetricRange1ColourHex],[MetricRange1Max],[MetricRange1Min],[MetricRange2ColourHex],[MetricRange2Max],[MetricRange2Min],[LanguageLabelId],[MetricEndAngle],[MetricMajorUnit],[MetricMax],[MetricMin],[MetricMinorUnit]) 
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254) AND [ShowMetric]=(1))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_GridViewDefinitions_Read]    Script Date: 02/02/2026 21:13:09 ******/
CREATE NONCLUSTERED INDEX [IX_GridViewDefinitions_Read] ON [SUserInterface].[GridViewDefinitions]
(
	[GridDefinitionId] ASC,
	[ID] ASC,
	[Code] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_GridViewDefinition_Code]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridViewDefinition_Code] ON [SUserInterface].[GridViewDefinitions]
(
	[GridDefinitionId] ASC,
	[Code] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]<>(0) AND [RowStatus]<>(254))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_GridViewDefinition_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridViewDefinition_Guid] ON [SUserInterface].[GridViewDefinitions]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_GridViewDefinition_SortOrder]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridViewDefinition_SortOrder] ON [SUserInterface].[GridViewDefinitions]
(
	[DisplayOrder] ASC,
	[GridDefinitionId] ASC,
	[RowStatus] ASC
)
WHERE ([RowStatus]=(1) AND [DisplayOrder]<>(0))
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_GridViewWidgetQueries]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_GridViewWidgetQueries] ON [SUserInterface].[GridViewWidgetQueries]
(
	[GridViewDefinitionId] ASC,
	[EntityQueryId] ASC,
	[WidgetTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_MetricTypes_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MetricTypes_Name] ON [SUserInterface].[Icons]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_MetricTypes_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MetricTypes_Guid] ON [SUserInterface].[MetricTypes]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 100, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_MetricTypes_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MetricTypes_Name] ON [SUserInterface].[MetricTypes]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
GO
/****** Object:  Index [IX_UQ_WidgetDashboards_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetDashboards_Guid] ON [SUserInterface].[WidgetDashboards]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_WidgetDashboards_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetDashboards_Name] ON [SUserInterface].[WidgetDashboards]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_WidgetDashboardWidgetTypes]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetDashboardWidgetTypes] ON [SUserInterface].[WidgetDashboardWidgetTypes]
(
	[WidgetDashboardId] ASC,
	[WidgetTypeId] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_WidgetDashboardWidgetTypes_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetDashboardWidgetTypes_Guid] ON [SUserInterface].[WidgetDashboardWidgetTypes]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
/****** Object:  Index [IX_UQ_WidgetTypes_Guid]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetTypes_Guid] ON [SUserInterface].[WidgetTypes]
(
	[Guid] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
SET ANSI_PADDING ON
GO
/****** Object:  Index [IX_UQ_WidgetTypes_Name]    Script Date: 02/02/2026 21:13:09 ******/
CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_WidgetTypes_Name] ON [SUserInterface].[WidgetTypes]
(
	[Name] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [METADATA]
GO
ALTER TABLE [SCore].[EntityDataTypes] ADD  CONSTRAINT [DF_EntityDataTypes_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityDataTypes] ADD  CONSTRAINT [DF_EntityDataTypes_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityDataTypes] ADD  CONSTRAINT [DF_EntityDataTypes_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[EntityDataTypes] ADD  CONSTRAINT [DF_EntityDataTypes_QuoteValue]  DEFAULT ((0)) FOR [QuoteValue]
GO
ALTER TABLE [SCore].[EntityHobts] ADD  CONSTRAINT [DF_EntityHoBTs_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityHobts] ADD  CONSTRAINT [DF_EntityHoBTs_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityHobts] ADD  CONSTRAINT [DF_EntityHoBTs_SchemaName]  DEFAULT ('') FOR [SchemaName]
GO
ALTER TABLE [SCore].[EntityHobts] ADD  CONSTRAINT [DF_EntityHoBTs_ObjectName]  DEFAULT ('') FOR [ObjectName]
GO
ALTER TABLE [SCore].[EntityHobts] ADD  CONSTRAINT [DF_EntityHoBTs_EntityTypeID]  DEFAULT ((-1)) FOR [EntityTypeID]
GO
ALTER TABLE [SCore].[EntityHobts] ADD  CONSTRAINT [DF_EntityHoBTs_ObjectType]  DEFAULT ('') FOR [ObjectType]
GO
ALTER TABLE [SCore].[EntityHobts] ADD  CONSTRAINT [DF_EntityHoBTs_IsMainHoBT]  DEFAULT ((0)) FOR [IsMainHoBT]
GO
ALTER TABLE [SCore].[EntityHobts] ADD  CONSTRAINT [DF_EntityHoBTs_IsReadOnlyOffline]  DEFAULT ((0)) FOR [IsReadOnlyOffline]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_LanguageLabelID]  DEFAULT ((-1)) FOR [LanguageLabelID]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_EntityHoBTID]  DEFAULT ((-1)) FOR [EntityHoBTID]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_EntityDateTypeID]  DEFAULT ((-1)) FOR [EntityDataTypeID]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsReadOnly]  DEFAULT ((0)) FOR [IsReadOnly]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsImmutable]  DEFAULT ((0)) FOR [IsImmutable]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsUppercase]  DEFAULT ((0)) FOR [IsUppercase]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsHidden]  DEFAULT ((0)) FOR [IsHidden]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsCompulsory]  DEFAULT ((0)) FOR [IsCompulsory]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_MaxLength]  DEFAULT ((0)) FOR [MaxLength]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_Precision]  DEFAULT ((0)) FOR [Precision]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_Scale]  DEFAULT ((0)) FOR [Scale]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_DoNotTrackChanges]  DEFAULT ((0)) FOR [DoNotTrackChanges]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_EntityPropertyGroupID]  DEFAULT ((-1)) FOR [EntityPropertyGroupID]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_GroupSortOrder]  DEFAULT ((0)) FOR [GroupSortOrder]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DEFAULT_EntityProperties_IsObjectLabel]  DEFAULT ((0)) FOR [IsObjectLabel]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_DropDownListDefinitionID]  DEFAULT ((-1)) FOR [DropDownListDefinitionID]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DEFAULT_EntityProperties_IsParentRelationship]  DEFAULT ((0)) FOR [IsParentRelationship]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsLongitude]  DEFAULT ((0)) FOR [IsLongitude]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsLatitude]  DEFAULT ((0)) FOR [IsLatitude]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsIncludedInformation]  DEFAULT ((0)) FOR [IsIncludedInformation]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_FixDefaultValue]  DEFAULT ('') FOR [FixedDefaultValue]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_SqlDefaultValueScript]  DEFAULT ('') FOR [SqlDefaultValueStatement]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_AllowBulkChange]  DEFAULT ((0)) FOR [AllowBulkChange]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsVirtual]  DEFAULT ((0)) FOR [IsVirtual]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_ShowOnMobile]  DEFAULT ((0)) FOR [ShowOnMobile]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsAlwaysVisibleInGroup]  DEFAULT ((0)) FOR [IsAlwaysVisibleInGroup]
GO
ALTER TABLE [SCore].[EntityProperties] ADD  CONSTRAINT [DF_EntityProperties_IsAlwaysVisibleInGroup_Mobile]  DEFAULT ((0)) FOR [IsAlwaysVisibleInGroup_Mobile]
GO
ALTER TABLE [SCore].[EntityPropertyActions] ADD  CONSTRAINT [DF_EntityPropertyActions_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityPropertyActions] ADD  CONSTRAINT [DF_EntityPropertyActions_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityPropertyActions] ADD  CONSTRAINT [DF_EntityPropertyActions_EntityPropertyID]  DEFAULT ((-1)) FOR [EntityPropertyID]
GO
ALTER TABLE [SCore].[EntityPropertyActions] ADD  CONSTRAINT [DF_EntityPropertyActions_Statement]  DEFAULT ('') FOR [Statement]
GO
ALTER TABLE [SCore].[EntityPropertyDependants] ADD  CONSTRAINT [DF_EEntityPropertyDependants_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityPropertyDependants] ADD  CONSTRAINT [DF_EEntityPropertyDependants_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityPropertyDependants] ADD  CONSTRAINT [DF_EEntityPropertyDependants_ParentEntityPropertyID]  DEFAULT ((-1)) FOR [ParentEntityPropertyID]
GO
ALTER TABLE [SCore].[EntityPropertyDependants] ADD  CONSTRAINT [DF_EEntityPropertyDependants_DependentEntityPropertyID]  DEFAULT ((-1)) FOR [DependantPropertyID]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_IsHidden]  DEFAULT ((0)) FOR [IsHidden]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_LanguageLabelID]  DEFAULT ((-1)) FOR [LanguageLabelID]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DEFAULT_EntityPropertyGroups_EntityTypeID]  DEFAULT ((-1)) FOR [EntityTypeID]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_PropertyGroupLayoutID]  DEFAULT ((-1)) FOR [PropertyGroupLayoutID]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_ShowOnMobile]  DEFAULT ((0)) FOR [ShowOnMobile]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_IsCollapsable]  DEFAULT ((0)) FOR [IsCollapsable]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_IsDefaultCollapsed]  DEFAULT ((0)) FOR [IsDefaultCollapsed]
GO
ALTER TABLE [SCore].[EntityPropertyGroups] ADD  CONSTRAINT [DF_EntityPropertyGroups_IsDefaultCollapsed_Moble]  DEFAULT ((0)) FOR [IsDefaultCollapsed_Mobile]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQuerues_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_Statement]  DEFAULT ('') FOR [Statement]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_EntityTypeID]  DEFAULT ((-1)) FOR [EntityTypeID]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DEFAULT_EntityQueries_EnityHoBTID]  DEFAULT ((-1)) FOR [EntityHoBTID]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_IsDefaultCreate]  DEFAULT ((0)) FOR [IsDefaultCreate]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_IsDefaultRead]  DEFAULT ((0)) FOR [IsDefaultRead]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_IsDefaultUpdate]  DEFAULT ((0)) FOR [IsDefaultUpdate]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_IsDefaultDelete]  DEFAULT ((0)) FOR [IsDefaultDelete]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_IsScalarExecute]  DEFAULT ((0)) FOR [IsScalarExecute]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DEFAULT_EntityQueries_IsDefaultValidation]  DEFAULT ((0)) FOR [IsDefaultValidation]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DEFAULT_EntityQueries_UsesProcessGuid]  DEFAULT ((0)) FOR [UsesProcessGuid]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DEFAULT_EntityQueries_IsDefaultDataPills]  DEFAULT ((0)) FOR [IsDefaultDataPills]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_IsProgressData]  DEFAULT ((0)) FOR [IsProgressData]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_IsMergeDocumentQuery]  DEFAULT ((0)) FOR [IsMergeDocumentQuery]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_SchemaName]  DEFAULT ('') FOR [SchemaName]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_ObjectName]  DEFAULT ('') FOR [ObjectName]
GO
ALTER TABLE [SCore].[EntityQueries] ADD  CONSTRAINT [DF_EntityQueries_IsManualStatement]  DEFAULT ((0)) FOR [IsManualStatement]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_EntityQueryID]  DEFAULT ((-1)) FOR [EntityQueryID]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_EntityDateTypeID]  DEFAULT ((-1)) FOR [EntityDataTypeID]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_EntityPropertyID]  DEFAULT ((-1)) FOR [MappedEntityPropertyID]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_DefaultValue]  DEFAULT ('') FOR [DefaultValue]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_IsInput]  DEFAULT ((0)) FOR [IsInput]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_IsOutput]  DEFAULT ((0)) FOR [IsOutput]
GO
ALTER TABLE [SCore].[EntityQueryParameters] ADD  CONSTRAINT [DF_EntityQueryParameters_IsReturnColumn]  DEFAULT ((0)) FOR [IsReturnColumn]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_IsReadOnlyOffline]  DEFAULT ((0)) FOR [IsReadOnlyOffline]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_IsRequiredSystemData]  DEFAULT ((0)) FOR [IsRequiredSystemData]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_HasDocuments]  DEFAULT ((0)) FOR [HasDocuments]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_LanguageLabelID]  DEFAULT ((-1)) FOR [LanguageLabelID]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_Entities_DoNotTrackChanges]  DEFAULT ((0)) FOR [DoNotTrackChanges]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_IsRootEntity]  DEFAULT ((0)) FOR [IsRootEntity]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_DetailPageUrl]  DEFAULT ('') FOR [DetailPageUrl]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  DEFAULT ((-1)) FOR [IconId]
GO
ALTER TABLE [SCore].[EntityTypes] ADD  CONSTRAINT [DF_EntityTypes_IsMetaData]  DEFAULT ((0)) FOR [IsMetaData]
GO
ALTER TABLE [SCore].[Groups] ADD  CONSTRAINT [DF_Groups_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[Groups] ADD  CONSTRAINT [DEFAULT_Groups_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[Groups] ADD  CONSTRAINT [DF_Groups_DirectoryId]  DEFAULT ('') FOR [DirectoryId]
GO
ALTER TABLE [SCore].[Groups] ADD  CONSTRAINT [DF_Groups_Code]  DEFAULT ('') FOR [Code]
GO
ALTER TABLE [SCore].[Groups] ADD  CONSTRAINT [DF_Groups_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[Groups] ADD  CONSTRAINT [DF_Groups_Source]  DEFAULT ('') FOR [Source]
GO
ALTER TABLE [SCore].[LanguageLabels] ADD  CONSTRAINT [DF_LanguageLabels_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[LanguageLabels] ADD  CONSTRAINT [DF_LanguageLabels_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[LanguageLabels] ADD  CONSTRAINT [DF_LanguageLabels_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] ADD  CONSTRAINT [DF_LanguageLabelTranslations_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] ADD  CONSTRAINT [DF_LanguageLabelTranslations_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] ADD  CONSTRAINT [DF_LanguageLabelTranslations_Text]  DEFAULT ('') FOR [Text]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] ADD  CONSTRAINT [DF_LanguageLabelTranslations_TextPlural]  DEFAULT ('') FOR [TextPlural]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] ADD  CONSTRAINT [DF_LanguageLabelTranslations_LanguageLabelID]  DEFAULT ((-1)) FOR [LanguageLabelID]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] ADD  CONSTRAINT [DF_LanguageLabelTranslations_LanguageID]  DEFAULT ((-1)) FOR [LanguageID]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] ADD  CONSTRAINT [DF_LanguageLabelTranslations_HelpText]  DEFAULT ('') FOR [HelpText]
GO
ALTER TABLE [SCore].[Languages] ADD  CONSTRAINT [DF_Languages_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[Languages] ADD  CONSTRAINT [DF_Languages_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[Languages] ADD  CONSTRAINT [DF_Languages_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[Languages] ADD  CONSTRAINT [DF_Languages_Local]  DEFAULT ('') FOR [Locale]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] ADD  CONSTRAINT [DF_MergeDocumentItemIncludes_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] ADD  CONSTRAINT [DF_MergeDocumentItemIncludes_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] ADD  CONSTRAINT [DF_MergeDocumentItemIncludes_MergeDocumentItemId]  DEFAULT ((-1)) FOR [MergeDocumentItemId]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] ADD  CONSTRAINT [DF_MergeDocumentItemIncludes_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] ADD  CONSTRAINT [DF_MergeDocumentItemIncludes_SourceDocumentEntityPropertyId]  DEFAULT ((-1)) FOR [SourceDocumentEntityPropertyId]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] ADD  CONSTRAINT [DF_MergeDocumentItemIncludes_SourceSharePointItemEntityPropertyId]  DEFAULT ((-1)) FOR [SourceSharePointItemEntityPropertyId]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] ADD  CONSTRAINT [DF_MergeDocumentItemIncludes_IncludedMergeDocumentId]  DEFAULT ((-1)) FOR [IncludedMergeDocumentId]
GO
ALTER TABLE [SCore].[MergeDocumentItems] ADD  CONSTRAINT [DF_Merge DocumentItems_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[MergeDocumentItems] ADD  CONSTRAINT [DF_Merge DocumentItems_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[MergeDocumentItems] ADD  CONSTRAINT [DF_Merge DocumentItems_MergeDocumentId]  DEFAULT ((-1)) FOR [MergeDocumentId]
GO
ALTER TABLE [SCore].[MergeDocumentItems] ADD  CONSTRAINT [DF_Merge DocumentItems_MergeDocumentItemTypeId]  DEFAULT ((-1)) FOR [MergeDocumentItemTypeId]
GO
ALTER TABLE [SCore].[MergeDocumentItems] ADD  CONSTRAINT [DF_Merge DocumentItems_BookmarkName]  DEFAULT ('') FOR [BookmarkName]
GO
ALTER TABLE [SCore].[MergeDocumentItems] ADD  CONSTRAINT [DF_Merge DocumentItems_EntityType]  DEFAULT ((-1)) FOR [EntityTypeId]
GO
ALTER TABLE [SCore].[MergeDocumentItems] ADD  CONSTRAINT [DF_Merge DocumentItems_SubFolderPath]  DEFAULT ('') FOR [SubFolderPath]
GO
ALTER TABLE [SCore].[MergeDocumentItems] ADD  CONSTRAINT [DF_Merge DocumentItems_ImageColumns]  DEFAULT ((0)) FOR [ImageColumns]
GO
ALTER TABLE [SCore].[MergeDocumentItemTypes] ADD  CONSTRAINT [DF_MergeDocumentItemTypes_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[MergeDocumentItemTypes] ADD  CONSTRAINT [DF_MergeDocumentItemTypes_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[MergeDocumentItemTypes] ADD  CONSTRAINT [DF_MergeDocumentItemTypes_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[MergeDocumentItemTypes] ADD  CONSTRAINT [DF_MergeDocumentItemTypes_IsImageType]  DEFAULT ((0)) FOR [IsImageType]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_FilenameTemplate]  DEFAULT ('') FOR [FilenameTemplate]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_EntityTypeId]  DEFAULT ((-1)) FOR [EntityTypeId]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_DocumentId]  DEFAULT ('') FOR [DocumentId]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_LinkedEntityTypeId]  DEFAULT ((-1)) FOR [LinkedEntityTypeId]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_SharepointSiteId]  DEFAULT ((-1)) FOR [SharepointSiteId]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_AllowPDFOutputOnly]  DEFAULT ((0)) FOR [AllowPDFOutputOnly]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_ProduceOneOutputPerRow]  DEFAULT ((0)) FOR [ProduceOneOutputPerRow]
GO
ALTER TABLE [SCore].[MergeDocuments] ADD  CONSTRAINT [DF_MergeDocuments_AllowExcelOutputOnly]  DEFAULT ((0)) FOR [AllowExcelOutputOnly]
GO
ALTER TABLE [SCore].[MergeDocumentTables] ADD  CONSTRAINT [DF_MergeDocumentTables_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[MergeDocumentTables] ADD  CONSTRAINT [DF_MergeDocumentTables_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[MergeDocumentTables] ADD  CONSTRAINT [DF_MergeDocumentTables_MergeDocumentId]  DEFAULT ((-1)) FOR [MergeDocumentId]
GO
ALTER TABLE [SCore].[MergeDocumentTables] ADD  CONSTRAINT [DF_MergeDocumentTables_TableName]  DEFAULT ('') FOR [TableName]
GO
ALTER TABLE [SCore].[MergeDocumentTables] ADD  CONSTRAINT [DF_MergeDocumentTables_LinkedEntityTypeId]  DEFAULT ((-1)) FOR [LinkedEntityTypeId]
GO
ALTER TABLE [SCore].[NonActivityEvents] ADD  CONSTRAINT [DF_NonActivityEvents_MemberId]  DEFAULT ((-1)) FOR [MemberIdentityId]
GO
ALTER TABLE [SCore].[NonActivityEvents] ADD  CONSTRAINT [DF__NonActivit__Guid__75709C27]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[NonActivityEvents] ADD  CONSTRAINT [DF__NonActivi__RowSt__7664C060]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[NonActivityEvents] ADD  CONSTRAINT [DF_NonActivityEvents_TeamId]  DEFAULT ((-1)) FOR [TeamGroupId]
GO
ALTER TABLE [SCore].[NonActivityEvents] ADD  CONSTRAINT [DF_NonActivityEvents_AbsenceTypeID]  DEFAULT ((-1)) FOR [AbsenceTypeID]
GO
ALTER TABLE [SCore].[NonActivityTypes] ADD  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[NonActivityTypes] ADD  CONSTRAINT [DF_NonActivityTypes_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[NonActivityTypes] ADD  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[RowStatus] ADD  CONSTRAINT [DF_RowStatus_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[Sectors] ADD  CONSTRAINT [DF_Sectors_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[Sectors] ADD  CONSTRAINT [DF_Sectors_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[Sectors] ADD  CONSTRAINT [DF_Sectors_Code]  DEFAULT ('') FOR [Code]
GO
ALTER TABLE [SCore].[Sectors] ADD  CONSTRAINT [DF_Sectors_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[Sectors] ADD  CONSTRAINT [DF_Sectors_Description]  DEFAULT ('') FOR [Description]
GO
ALTER TABLE [SCore].[SequenceTable] ADD  CONSTRAINT [DF_SequenceTable_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[SequenceTable] ADD  CONSTRAINT [DF_SequenceTable_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[SequenceTable] ADD  CONSTRAINT [DF_SequenceTable_SysName]  DEFAULT ('') FOR [SysName]
GO
ALTER TABLE [SCore].[SequenceTable] ADD  CONSTRAINT [DF_SequenceTable_FriendlyName]  DEFAULT ('') FOR [FriendlyName]
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
ALTER TABLE [SCore].[Versioning] ADD  CONSTRAINT [DF_Versioning_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[Versioning] ADD  CONSTRAINT [DF_Versioning_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[Versioning] ADD  CONSTRAINT [DF_Versioning_Version]  DEFAULT ('') FOR [Version]
GO
ALTER TABLE [SCore].[Versioning] ADD  CONSTRAINT [DF_Versioning_Name]  DEFAULT ('') FOR [Description]
GO
ALTER TABLE [SCore].[Versioning] ADD  CONSTRAINT [DF_Versioning_Current]  DEFAULT ((0)) FOR [IsCurrent]
GO
ALTER TABLE [SCore].[Workflow] ADD  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[Workflow] ADD  CONSTRAINT [DF_Workflow_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[Workflow] ADD  CONSTRAINT [DF_DataObjectTransition_OrganisationalUnitId]  DEFAULT ((-1)) FOR [OrganisationalUnitId]
GO
ALTER TABLE [SCore].[Workflow] ADD  CONSTRAINT [DF_DataObjectTransition_EntityTypeID]  DEFAULT ((-1)) FOR [EntityTypeID]
GO
ALTER TABLE [SCore].[Workflow] ADD  CONSTRAINT [DF_Workflow_EntityHoBTID]  DEFAULT ((-1)) FOR [EntityHoBTID]
GO
ALTER TABLE [SCore].[Workflow] ADD  CONSTRAINT [DF_Workflow_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[Workflow] ADD  DEFAULT ((1)) FOR [Enabled]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_OrganisationalUnitId]  DEFAULT ((-1)) FOR [OrganisationalUnitId]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_Description]  DEFAULT ('') FOR [Description]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  DEFAULT ((0)) FOR [ShowInEnquiries]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  DEFAULT ((0)) FOR [ShowInQuotes]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  DEFAULT ((0)) FOR [ShowInJobs]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  DEFAULT ((1)) FOR [Enabled]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  DEFAULT ((0)) FOR [IsPredefined]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  DEFAULT ('#FFFFFF') FOR [Colour]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_SendNotification]  DEFAULT ((0)) FOR [SendNotification]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_IsCompleteStatus]  DEFAULT ((0)) FOR [IsCompleteStatus]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_IsCustomerWaitingStatus]  DEFAULT ((0)) FOR [IsCustomerWaitingStatus]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_RequiresUsersAction]  DEFAULT ((0)) FOR [RequiresUsersAction]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_IsActiveStatus]  DEFAULT ((0)) FOR [IsActiveStatus]
GO
ALTER TABLE [SCore].[WorkflowStatus] ADD  CONSTRAINT [DF_WorkflowStatus_AuthorisationNeeded]  DEFAULT ((0)) FOR [AuthorisationNeeded]
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] ADD  CONSTRAINT [DF_WorkflowStatusNotificationGroups_RowStatus]  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] ADD  CONSTRAINT [DF_WorkflowStatusNotificationGroups_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] ADD  CONSTRAINT [DF_WorkflowStatusNotificationGroups_WorkflowID]  DEFAULT ((-1)) FOR [WorkflowID]
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] ADD  CONSTRAINT [DF_WorkflowStatusNotificationGroups_WorkflowStatusGuid]  DEFAULT (newid()) FOR [WorkflowStatusGuid]
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] ADD  CONSTRAINT [DF_WorkflowStatusNotificationGroups_GroupID]  DEFAULT ((-1)) FOR [GroupID]
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] ADD  CONSTRAINT [DF_WorkflowStatusNotificationGroups_CanAction]  DEFAULT ((0)) FOR [CanAction]
GO
ALTER TABLE [SCore].[WorkflowTransition] ADD  DEFAULT ((1)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[WorkflowTransition] ADD  CONSTRAINT [DF_WorkflowTransition_WorkflowID]  DEFAULT ((-1)) FOR [WorkflowID]
GO
ALTER TABLE [SCore].[WorkflowTransition] ADD  CONSTRAINT [DF_WorkflowTransition_FromStatusID]  DEFAULT ((-1)) FOR [FromStatusID]
GO
ALTER TABLE [SCore].[WorkflowTransition] ADD  CONSTRAINT [DF_WorkflowTransition_ToStatusID]  DEFAULT ((-1)) FOR [ToStatusID]
GO
ALTER TABLE [SCore].[WorkflowTransition] ADD  DEFAULT ((0)) FOR [IsFinal]
GO
ALTER TABLE [SCore].[WorkflowTransition] ADD  DEFAULT ((1)) FOR [Enabled]
GO
ALTER TABLE [SCore].[WorkflowTransition] ADD  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [SCore].[WorkflowTransition] ADD  CONSTRAINT [DF_WorkflowTransition_Description]  DEFAULT (N'') FOR [Description]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_LanguageLabelId]  DEFAULT ((-1)) FOR [LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_IconCss]  DEFAULT ('') FOR [IconCss]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_Type]  DEFAULT ('') FOR [Type]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_EntityTypeId]  DEFAULT ((-1)) FOR [EntityTypeId]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_EntityQueryId]  DEFAULT ((-1)) FOR [EntityQueryId]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] ADD  CONSTRAINT [DF_ActionMenuItems_RedirectToTargetGuid]  DEFAULT ((0)) FOR [RedirectToTargetGuid]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinition_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DEFAULT_DropDownListDefinitions_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinition_Code]  DEFAULT ('') FOR [Code]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinition_NameColumn]  DEFAULT ('') FOR [NameColumn]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinition_ValueColumn]  DEFAULT ('') FOR [ValueColumn]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinition_SqlQuery]  DEFAULT ('') FOR [SqlQuery]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinition_DefaultSortColumnName]  DEFAULT (N'ID') FOR [DefaultSortColumnName]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinition_IdDefaultColumn]  DEFAULT ('') FOR [IsDefaultColumn]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinitions_DetailPageUrl]  DEFAULT ('') FOR [DetailPageUrl]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinitions_IsDetailWindowed]  DEFAULT ((0)) FOR [IsDetailWindowed]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinitions_EntityTypeId]  DEFAULT ((-1)) FOR [EntityTypeId]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinitions_InformationPageUrl]  DEFAULT ('') FOR [InformationPageUrl]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinitions_GroupColumn]  DEFAULT ('') FOR [GroupColumn]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinitions_ColourHexColumn]  DEFAULT ('#000000') FOR [ColourHexColumn]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] ADD  CONSTRAINT [DF_DropDownListDefinitions_ExternalSearchPageUrl]  DEFAULT ('') FOR [ExternalSearchPageUrl]
GO
ALTER TABLE [SUserInterface].[GridDefinitions] ADD  CONSTRAINT [DF_GridDefinition_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[GridDefinitions] ADD  CONSTRAINT [DEFAULT_GridDefinitions_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[GridDefinitions] ADD  CONSTRAINT [DF_GridDefinition_Code]  DEFAULT ('') FOR [Code]
GO
ALTER TABLE [SUserInterface].[GridDefinitions] ADD  CONSTRAINT [DF_GridDefinition_PageUri]  DEFAULT ('') FOR [PageUri]
GO
ALTER TABLE [SUserInterface].[GridDefinitions] ADD  CONSTRAINT [DF_GridDefinition_TabName]  DEFAULT ('') FOR [TabName]
GO
ALTER TABLE [SUserInterface].[GridDefinitions] ADD  CONSTRAINT [DF_GridDefinition_ShowAsTiles]  DEFAULT ((0)) FOR [ShowAsTiles]
GO
ALTER TABLE [SUserInterface].[GridDefinitions] ADD  DEFAULT ((-1)) FOR [LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[GridViewActions] ADD  CONSTRAINT [DF_GridViewActions_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewActions] ADD  CONSTRAINT [DEFAULT_GridViewActions_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[GridViewActions] ADD  CONSTRAINT [DF_GridViewActions_GridViewDefinitionId]  DEFAULT ((-1)) FOR [GridViewDefinitionId]
GO
ALTER TABLE [SUserInterface].[GridViewActions] ADD  DEFAULT ((-1)) FOR [LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[GridViewActions] ADD  CONSTRAINT [DF_GridViewActions_EntityQueryId]  DEFAULT ((-1)) FOR [EntityQueryId]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinition_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewColumnDefinitions_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinition_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinition_order]  DEFAULT ((0)) FOR [ColumnOrder]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinition_GridViewDefinitionId]  DEFAULT ((-1)) FOR [GridViewDefinitionId]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinition_IsPrimaryKey]  DEFAULT ((0)) FOR [IsPrimaryKey]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinition_IsHidden]  DEFAULT ((0)) FOR [IsHidden]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinition_IsFiltered]  DEFAULT ((0)) FOR [IsFiltered]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinition_IsCombo]  DEFAULT ((0)) FOR [IsCombo]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewColumnDefinitions_IsLongitude]  DEFAULT ((0)) FOR [IsLongitude]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewColumnDefinitions_IsLatitude]  DEFAULT ((0)) FOR [IsLatitude]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinitions_DisplayFormat]  DEFAULT ('') FOR [DisplayFormat]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinitions_Width]  DEFAULT ('') FOR [Width]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  DEFAULT ((-1)) FOR [LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  DEFAULT ('') FOR [TopHeaderCategory]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] ADD  DEFAULT ((0)) FOR [TopHeaderCategoryOrder]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_Code]  DEFAULT ('') FOR [Code]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_GridDefinitionId]  DEFAULT ((-1)) FOR [GridDefinitionId]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_DetailPageUri]  DEFAULT ('') FOR [DetailPageUri]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_SqlQuery]  DEFAULT ('') FOR [SqlQuery]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_DefaultSortColumnName]  DEFAULT (N'ID') FOR [DefaultSortColumnName]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_SecurableCode]  DEFAULT (N'') FOR [SecurableCode]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_DisplayOrder]  DEFAULT ((0)) FOR [DisplayOrder]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_DisplayGroupName]  DEFAULT (N'') FOR [DisplayGroupName]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinition_TileSqlQuery]  DEFAULT (N'') FOR [MetricSqlQuery]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_ShowMetric]  DEFAULT ((0)) FOR [ShowMetric]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_IsDetailWindowed]  DEFAULT ((0)) FOR [IsDetailWindowed]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_EntityTypeID]  DEFAULT ((-1)) FOR [EntityTypeID]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricTypeID]  DEFAULT ((-1)) FOR [MetricTypeID]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricMin]  DEFAULT ((0)) FOR [MetricMin]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricMax]  DEFAULT ((0)) FOR [MetricMax]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricMinorUnit]  DEFAULT ((0)) FOR [MetricMinorUnit]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricMajorUnit]  DEFAULT ((0)) FOR [MetricMajorUnit]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricStartAngle]  DEFAULT ((0)) FOR [MetricStartAngle]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricEndAngle]  DEFAULT ((0)) FOR [MetricEndAngle]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricReversed]  DEFAULT ((0)) FOR [MetricReversed]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange1Min]  DEFAULT ((0)) FOR [MetricRange1Min]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange1Max]  DEFAULT ((0)) FOR [MetricRange1Max]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange1ColourHex]  DEFAULT ('') FOR [MetricRange1ColourHex]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange2Min]  DEFAULT ((0)) FOR [MetricRange2Min]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange2Max]  DEFAULT ((0)) FOR [MetricRange2Max]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DEFAULT_GridViewDefinitions_MetricRange2ColourHex]  DEFAULT ('') FOR [MetricRange2ColourHex]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_IsDefaultSortDescending]  DEFAULT ((0)) FOR [IsDefaultSortDescending]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_AllowNew]  DEFAULT ((0)) FOR [AllowNew]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_AllowExcelExport]  DEFAULT ((0)) FOR [AllowExcelExport]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_AllowPdfExport]  DEFAULT ((0)) FOR [AllowPdfExport]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_AllowCsvExport]  DEFAULT ((0)) FOR [AllowCsvExport]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_LanguageLabelId]  DEFAULT ((-1)) FOR [LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_DrawIconId]  DEFAULT ((-1)) FOR [DrawerIconId]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_GridViewTypeId]  DEFAULT ((-1)) FOR [GridViewTypeId]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_AllowBulkChange]  DEFAULT ((0)) FOR [AllowBulkChange]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_IsMobile]  DEFAULT ((0)) FOR [ShowOnMobile]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinitions_TreeListFirstOrderBy]  DEFAULT ('') FOR [TreeListFirstOrderBy]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinitions_TreeListSecondOrderBy]  DEFAULT ('') FOR [TreeListSecondOrderBy]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinitions_TreeListThirdOrderBy]  DEFAULT ('') FOR [TreeListThirdOrderBy]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinitions_TreeListOrderBy]  DEFAULT ('') FOR [TreeListOrderBy]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewColumnDefinitions_TreeListGroupBy]  DEFAULT ('') FOR [TreeListGroupBy]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  CONSTRAINT [DF_GridViewDefinitions_ShowOnDashboard]  DEFAULT ((0)) FOR [ShowOnDashboard]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  DEFAULT (N'') FOR [FilteredListCreatedOnColumn]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  DEFAULT (N'') FOR [FilteredListRedStatusIndicatorTxt]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  DEFAULT (N'') FOR [FilteredListOrangeStatusIndicatorTxt]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  DEFAULT (N'') FOR [FilteredListGreenStatusIndicatorTxt]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] ADD  DEFAULT (N'') FOR [FilteredListGroupBy]
GO
ALTER TABLE [SUserInterface].[GridViewTypes] ADD  CONSTRAINT [DF_GridViewTypes_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewTypes] ADD  CONSTRAINT [DEFAULT_GridViewTypes_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[GridViewTypes] ADD  CONSTRAINT [DF_GridViewTypes_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] ADD  CONSTRAINT [DF_GridViewWidgetQueries_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] ADD  CONSTRAINT [DF_GridViewWidgetQueries_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] ADD  CONSTRAINT [DF_GridViewWidgetQueries_GridViewDefinitionId]  DEFAULT ((-1)) FOR [GridViewDefinitionId]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] ADD  CONSTRAINT [DF_GridViewWidgetQueries_EntityQueryId]  DEFAULT ((-1)) FOR [EntityQueryId]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] ADD  CONSTRAINT [DF_GridViewWidgetQueries_WidgetTypeId]  DEFAULT ((-1)) FOR [WidgetTypeId]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] ADD  CONSTRAINT [DF_GridViewWidgetQueries_LanguageLabelID]  DEFAULT ((-1)) FOR [LanguageLabelID]
GO
ALTER TABLE [SUserInterface].[Icons] ADD  CONSTRAINT [DC_Icons_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[Icons] ADD  CONSTRAINT [DC_Icons_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[Icons] ADD  CONSTRAINT [DC_Icons_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SUserInterface].[MainMenuItems] ADD  CONSTRAINT [DF_MainMenuItems_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[MainMenuItems] ADD  CONSTRAINT [DEFAULT_MainMenuItems_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[MainMenuItems] ADD  CONSTRAINT [DF__MainMenuI__Langu__37F1C144]  DEFAULT ((-1)) FOR [LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[MainMenuItems] ADD  CONSTRAINT [DF_MainMenuItems_IconId]  DEFAULT ((-1)) FOR [IconId]
GO
ALTER TABLE [SUserInterface].[MainMenuItems] ADD  CONSTRAINT [DF_MainMenuItems_NavigationUrl]  DEFAULT ('') FOR [NavigationUrl]
GO
ALTER TABLE [SUserInterface].[MainMenuItems] ADD  CONSTRAINT [DF_MainMenuItems_SortOrder]  DEFAULT ((0)) FOR [SortOrder]
GO
ALTER TABLE [SUserInterface].[MetricTypes] ADD  CONSTRAINT [DF_MetricTypes_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[MetricTypes] ADD  CONSTRAINT [DEFAULT_MetricTypes_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[MetricTypes] ADD  CONSTRAINT [DF_MetricTypes_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SUserInterface].[PropertyGroupLayouts] ADD  CONSTRAINT [DF_PropertyGroupLayouts_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[PropertyGroupLayouts] ADD  CONSTRAINT [DEFAULT_PropertyGroupLayouts_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[PropertyGroupLayouts] ADD  CONSTRAINT [DF_PropertyGroupLayouts_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SUserInterface].[WidgetDashboards] ADD  CONSTRAINT [DF_WidgetDashboards_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[WidgetDashboards] ADD  CONSTRAINT [DF_WidgetDashboards_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[WidgetDashboards] ADD  CONSTRAINT [DF_WidgetDashboards_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SUserInterface].[WidgetDashboards] ADD  CONSTRAINT [DF_WidgetDashboards_ParentEntityTypeId]  DEFAULT ((-1)) FOR [ParentEntityTypeId]
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] ADD  CONSTRAINT [DF_WidgetDashboardWidgetTypes_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] ADD  CONSTRAINT [DF_WidgetDashboardWidgetTypes_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] ADD  CONSTRAINT [DF_WidgetDashboardWidgetTypes_WidgetDashboardId]  DEFAULT ((-1)) FOR [WidgetDashboardId]
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] ADD  CONSTRAINT [DF_WidgetDashboardWidgetTypes_WidgetTypeId]  DEFAULT ((-1)) FOR [WidgetTypeId]
GO
ALTER TABLE [SUserInterface].[WidgetTypes] ADD  CONSTRAINT [DF_WidgetTypes_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SUserInterface].[WidgetTypes] ADD  CONSTRAINT [DF_WidgetTypes_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SUserInterface].[WidgetTypes] ADD  CONSTRAINT [DF_WidgetTypes_Name]  DEFAULT ('') FOR [Name]
GO
ALTER TABLE [SCore].[EntityDataTypes]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityDataTypes_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[EntityDataTypes] CHECK CONSTRAINT [FK_EntityDataTypes_DataObjects]
GO
ALTER TABLE [SCore].[EntityDataTypes]  WITH CHECK ADD  CONSTRAINT [FK_EntityDataTypes_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityDataTypes] CHECK CONSTRAINT [FK_EntityDataTypes_RowStatus]
GO
ALTER TABLE [SCore].[EntityHobts]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityHobts_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[EntityHobts] CHECK CONSTRAINT [FK_EntityHobts_DataObjects]
GO
ALTER TABLE [SCore].[EntityHobts]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityHoBTs_EntityTypes] FOREIGN KEY([EntityTypeID])
REFERENCES [SCore].[EntityTypes] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[EntityHobts] CHECK CONSTRAINT [FK_EntityHoBTs_EntityTypes]
GO
ALTER TABLE [SCore].[EntityHobts]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityHobts_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityHobts] CHECK CONSTRAINT [FK_EntityHobts_RowStatus]
GO
ALTER TABLE [SCore].[EntityProperties]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityProperties_DropDownListDefinitions] FOREIGN KEY([DropDownListDefinitionID])
REFERENCES [SUserInterface].[DropDownListDefinitions] ([ID])
GO
ALTER TABLE [SCore].[EntityProperties] CHECK CONSTRAINT [FK_EntityProperties_DropDownListDefinitions]
GO
ALTER TABLE [SCore].[EntityProperties]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityProperties_EntityDataTypes] FOREIGN KEY([EntityDataTypeID])
REFERENCES [SCore].[EntityDataTypes] ([ID])
GO
ALTER TABLE [SCore].[EntityProperties] CHECK CONSTRAINT [FK_EntityProperties_EntityDataTypes]
GO
ALTER TABLE [SCore].[EntityProperties]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityProperties_EntityHoBTs] FOREIGN KEY([EntityHoBTID])
REFERENCES [SCore].[EntityHobts] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[EntityProperties] CHECK CONSTRAINT [FK_EntityProperties_EntityHoBTs]
GO
ALTER TABLE [SCore].[EntityProperties]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityProperties_EntityPropertyGroupID] FOREIGN KEY([EntityPropertyGroupID])
REFERENCES [SCore].[EntityPropertyGroups] ([ID])
GO
ALTER TABLE [SCore].[EntityProperties] CHECK CONSTRAINT [FK_EntityProperties_EntityPropertyGroupID]
GO
ALTER TABLE [SCore].[EntityProperties]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityProperties_LanguageLabels] FOREIGN KEY([LanguageLabelID])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SCore].[EntityProperties] CHECK CONSTRAINT [FK_EntityProperties_LanguageLabels]
GO
ALTER TABLE [SCore].[EntityProperties]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityProperties_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityProperties] CHECK CONSTRAINT [FK_EntityProperties_RowStatus]
GO
ALTER TABLE [SCore].[EntityPropertyActions]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityPropertyActions_EntityProperties] FOREIGN KEY([EntityPropertyID])
REFERENCES [SCore].[EntityProperties] ([ID])
GO
ALTER TABLE [SCore].[EntityPropertyActions] CHECK CONSTRAINT [FK_EntityPropertyActions_EntityProperties]
GO
ALTER TABLE [SCore].[EntityPropertyActions]  WITH CHECK ADD  CONSTRAINT [FK_EntityPropertyActions_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityPropertyActions] CHECK CONSTRAINT [FK_EntityPropertyActions_RowStatus]
GO
ALTER TABLE [SCore].[EntityPropertyDependants]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityPropertyDependants_EntityProperties] FOREIGN KEY([ParentEntityPropertyID])
REFERENCES [SCore].[EntityProperties] ([ID])
GO
ALTER TABLE [SCore].[EntityPropertyDependants] CHECK CONSTRAINT [FK_EntityPropertyDependants_EntityProperties]
GO
ALTER TABLE [SCore].[EntityPropertyDependants]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityPropertyDependants_EntityProperties1] FOREIGN KEY([DependantPropertyID])
REFERENCES [SCore].[EntityProperties] ([ID])
GO
ALTER TABLE [SCore].[EntityPropertyDependants] CHECK CONSTRAINT [FK_EntityPropertyDependants_EntityProperties1]
GO
ALTER TABLE [SCore].[EntityPropertyDependants]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityPropertyDependants_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityPropertyDependants] CHECK CONSTRAINT [FK_EntityPropertyDependants_RowStatus]
GO
ALTER TABLE [SCore].[EntityPropertyGroups]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityPropertyGroups_EntityTypes] FOREIGN KEY([EntityTypeID])
REFERENCES [SCore].[EntityTypes] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[EntityPropertyGroups] CHECK CONSTRAINT [FK_EntityPropertyGroups_EntityTypes]
GO
ALTER TABLE [SCore].[EntityPropertyGroups]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityPropertyGroups_LanguageLabels] FOREIGN KEY([LanguageLabelID])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SCore].[EntityPropertyGroups] CHECK CONSTRAINT [FK_EntityPropertyGroups_LanguageLabels]
GO
ALTER TABLE [SCore].[EntityPropertyGroups]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityPropertyGroups_PropertyGroupLayouts] FOREIGN KEY([PropertyGroupLayoutID])
REFERENCES [SUserInterface].[PropertyGroupLayouts] ([ID])
GO
ALTER TABLE [SCore].[EntityPropertyGroups] CHECK CONSTRAINT [FK_EntityPropertyGroups_PropertyGroupLayouts]
GO
ALTER TABLE [SCore].[EntityPropertyGroups]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityPropertyGroups_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityPropertyGroups] CHECK CONSTRAINT [FK_EntityPropertyGroups_RowStatus]
GO
ALTER TABLE [SCore].[EntityQueries]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueries_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[EntityQueries] CHECK CONSTRAINT [FK_EntityQueries_DataObjects]
GO
ALTER TABLE [SCore].[EntityQueries]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueries_EntityHoBTs] FOREIGN KEY([EntityHoBTID])
REFERENCES [SCore].[EntityHobts] ([ID])
GO
ALTER TABLE [SCore].[EntityQueries] CHECK CONSTRAINT [FK_EntityQueries_EntityHoBTs]
GO
ALTER TABLE [SCore].[EntityQueries]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueries_EntityTypes] FOREIGN KEY([EntityTypeID])
REFERENCES [SCore].[EntityTypes] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[EntityQueries] CHECK CONSTRAINT [FK_EntityQueries_EntityTypes]
GO
ALTER TABLE [SCore].[EntityQueries]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueries_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityQueries] CHECK CONSTRAINT [FK_EntityQueries_RowStatus]
GO
ALTER TABLE [SCore].[EntityQueryParameters]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueryParameters_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[EntityQueryParameters] CHECK CONSTRAINT [FK_EntityQueryParameters_DataObjects]
GO
ALTER TABLE [SCore].[EntityQueryParameters]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueryParameters_EntityDataTypes] FOREIGN KEY([EntityDataTypeID])
REFERENCES [SCore].[EntityDataTypes] ([ID])
GO
ALTER TABLE [SCore].[EntityQueryParameters] CHECK CONSTRAINT [FK_EntityQueryParameters_EntityDataTypes]
GO
ALTER TABLE [SCore].[EntityQueryParameters]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueryParameters_EntityProperties] FOREIGN KEY([MappedEntityPropertyID])
REFERENCES [SCore].[EntityProperties] ([ID])
GO
ALTER TABLE [SCore].[EntityQueryParameters] CHECK CONSTRAINT [FK_EntityQueryParameters_EntityProperties]
GO
ALTER TABLE [SCore].[EntityQueryParameters]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueryParameters_EntityQueries] FOREIGN KEY([EntityQueryID])
REFERENCES [SCore].[EntityQueries] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[EntityQueryParameters] CHECK CONSTRAINT [FK_EntityQueryParameters_EntityQueries]
GO
ALTER TABLE [SCore].[EntityQueryParameters]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityQueryParameters_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityQueryParameters] CHECK CONSTRAINT [FK_EntityQueryParameters_RowStatus]
GO
ALTER TABLE [SCore].[EntityTypes]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityTypes_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[EntityTypes] CHECK CONSTRAINT [FK_EntityTypes_DataObjects]
GO
ALTER TABLE [SCore].[EntityTypes]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityTypes_IconId] FOREIGN KEY([IconId])
REFERENCES [SUserInterface].[Icons] ([ID])
GO
ALTER TABLE [SCore].[EntityTypes] CHECK CONSTRAINT [FK_EntityTypes_IconId]
GO
ALTER TABLE [SCore].[EntityTypes]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityTypes_LanguageLabels] FOREIGN KEY([LanguageLabelID])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SCore].[EntityTypes] CHECK CONSTRAINT [FK_EntityTypes_LanguageLabels]
GO
ALTER TABLE [SCore].[EntityTypes]  WITH NOCHECK ADD  CONSTRAINT [FK_EntityTypes_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[EntityTypes] CHECK CONSTRAINT [FK_EntityTypes_RowStatus]
GO
ALTER TABLE [SCore].[Groups]  WITH NOCHECK ADD  CONSTRAINT [FK_Groups_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[Groups] CHECK CONSTRAINT [FK_Groups_DataObjects]
GO
ALTER TABLE [SCore].[Groups]  WITH CHECK ADD  CONSTRAINT [FK_Groups_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[Groups] CHECK CONSTRAINT [FK_Groups_RowStatus]
GO
ALTER TABLE [SCore].[LanguageLabels]  WITH NOCHECK ADD  CONSTRAINT [FK_LanguageLabels_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[LanguageLabels] CHECK CONSTRAINT [FK_LanguageLabels_DataObjects]
GO
ALTER TABLE [SCore].[LanguageLabels]  WITH NOCHECK ADD  CONSTRAINT [FK_LanguageLabels_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[LanguageLabels] CHECK CONSTRAINT [FK_LanguageLabels_RowStatus]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations]  WITH NOCHECK ADD  CONSTRAINT [FK_LanguageLabelTranslations_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] CHECK CONSTRAINT [FK_LanguageLabelTranslations_DataObjects]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations]  WITH NOCHECK ADD  CONSTRAINT [FK_LanguageLabelTranslations_LanguageLabels] FOREIGN KEY([LanguageLabelID])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] CHECK CONSTRAINT [FK_LanguageLabelTranslations_LanguageLabels]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations]  WITH NOCHECK ADD  CONSTRAINT [FK_LanguageLabelTranslations_Languages] FOREIGN KEY([LanguageID])
REFERENCES [SCore].[Languages] ([ID])
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] CHECK CONSTRAINT [FK_LanguageLabelTranslations_Languages]
GO
ALTER TABLE [SCore].[LanguageLabelTranslations]  WITH NOCHECK ADD  CONSTRAINT [FK_LanguageLabelTranslations_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[LanguageLabelTranslations] CHECK CONSTRAINT [FK_LanguageLabelTranslations_RowStatus]
GO
ALTER TABLE [SCore].[Languages]  WITH NOCHECK ADD  CONSTRAINT [FK_Languages_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[Languages] CHECK CONSTRAINT [FK_Languages_DataObjects]
GO
ALTER TABLE [SCore].[Languages]  WITH CHECK ADD  CONSTRAINT [FK_Languages_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[Languages] CHECK CONSTRAINT [FK_Languages_RowStatus]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes]  WITH NOCHECK ADD  CONSTRAINT [FK_MergeDocumentItemIncludes_EntityProperties] FOREIGN KEY([SourceDocumentEntityPropertyId])
REFERENCES [SCore].[EntityProperties] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] CHECK CONSTRAINT [FK_MergeDocumentItemIncludes_EntityProperties]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocumentItemIncludes_EntityProperties1] FOREIGN KEY([SourceSharePointItemEntityPropertyId])
REFERENCES [SCore].[EntityProperties] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] CHECK CONSTRAINT [FK_MergeDocumentItemIncludes_EntityProperties1]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocumentItemIncludes_MergeDocumentItems] FOREIGN KEY([MergeDocumentItemId])
REFERENCES [SCore].[MergeDocumentItems] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] CHECK CONSTRAINT [FK_MergeDocumentItemIncludes_MergeDocumentItems]
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocumentItemIncludes_MergeDocuments] FOREIGN KEY([IncludedMergeDocumentId])
REFERENCES [SCore].[MergeDocuments] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentItemIncludes] CHECK CONSTRAINT [FK_MergeDocumentItemIncludes_MergeDocuments]
GO
ALTER TABLE [SCore].[MergeDocumentItems]  WITH NOCHECK ADD  CONSTRAINT [FK_MergeDocumentItems_EntityTypes] FOREIGN KEY([EntityTypeId])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentItems] CHECK CONSTRAINT [FK_MergeDocumentItems_EntityTypes]
GO
ALTER TABLE [SCore].[MergeDocumentItems]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocumentItems_MergeDocumentItemTypes] FOREIGN KEY([MergeDocumentItemTypeId])
REFERENCES [SCore].[MergeDocumentItemTypes] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentItems] CHECK CONSTRAINT [FK_MergeDocumentItems_MergeDocumentItemTypes]
GO
ALTER TABLE [SCore].[MergeDocumentItems]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocumentItems_MergeDocuments] FOREIGN KEY([MergeDocumentId])
REFERENCES [SCore].[MergeDocuments] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentItems] CHECK CONSTRAINT [FK_MergeDocumentItems_MergeDocuments]
GO
ALTER TABLE [SCore].[MergeDocuments]  WITH NOCHECK ADD  CONSTRAINT [FK_MergeDocuments_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[MergeDocuments] CHECK CONSTRAINT [FK_MergeDocuments_DataObjects]
GO
ALTER TABLE [SCore].[MergeDocuments]  WITH NOCHECK ADD  CONSTRAINT [FK_MergeDocuments_EntityTypes] FOREIGN KEY([EntityTypeId])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SCore].[MergeDocuments] CHECK CONSTRAINT [FK_MergeDocuments_EntityTypes]
GO
ALTER TABLE [SCore].[MergeDocuments]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocuments_EntityTypes1] FOREIGN KEY([LinkedEntityTypeId])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SCore].[MergeDocuments] CHECK CONSTRAINT [FK_MergeDocuments_EntityTypes1]
GO
ALTER TABLE [SCore].[MergeDocuments]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocuments_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[MergeDocuments] CHECK CONSTRAINT [FK_MergeDocuments_RowStatus]
GO
ALTER TABLE [SCore].[MergeDocuments]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocuments_SharepointSites] FOREIGN KEY([SharepointSiteId])
REFERENCES [SCore].[SharepointSites] ([ID])
GO
ALTER TABLE [SCore].[MergeDocuments] CHECK CONSTRAINT [FK_MergeDocuments_SharepointSites]
GO
ALTER TABLE [SCore].[MergeDocumentTables]  WITH NOCHECK ADD  CONSTRAINT [FK_MergeDocumentTables_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[MergeDocumentTables] CHECK CONSTRAINT [FK_MergeDocumentTables_DataObjects]
GO
ALTER TABLE [SCore].[MergeDocumentTables]  WITH NOCHECK ADD  CONSTRAINT [FK_MergeDocumentTables_EntityTypes] FOREIGN KEY([LinkedEntityTypeId])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentTables] CHECK CONSTRAINT [FK_MergeDocumentTables_EntityTypes]
GO
ALTER TABLE [SCore].[MergeDocumentTables]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocumentTables_MergeDocuments] FOREIGN KEY([MergeDocumentId])
REFERENCES [SCore].[MergeDocuments] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SCore].[MergeDocumentTables] CHECK CONSTRAINT [FK_MergeDocumentTables_MergeDocuments]
GO
ALTER TABLE [SCore].[MergeDocumentTables]  WITH CHECK ADD  CONSTRAINT [FK_MergeDocumentTables_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[MergeDocumentTables] CHECK CONSTRAINT [FK_MergeDocumentTables_RowStatus]
GO
ALTER TABLE [SCore].[NonActivityEvents]  WITH CHECK ADD  CONSTRAINT [FK_NonActivityEvents_AbsenceTypes] FOREIGN KEY([AbsenceTypeID])
REFERENCES [SCore].[NonActivityTypes] ([ID])
GO
ALTER TABLE [SCore].[NonActivityEvents] CHECK CONSTRAINT [FK_NonActivityEvents_AbsenceTypes]
GO
ALTER TABLE [SCore].[NonActivityEvents]  WITH CHECK ADD  CONSTRAINT [FK_NonActivityEvents_Groups] FOREIGN KEY([TeamGroupId])
REFERENCES [SCore].[Groups] ([ID])
GO
ALTER TABLE [SCore].[NonActivityEvents] CHECK CONSTRAINT [FK_NonActivityEvents_Groups]
GO
ALTER TABLE [SCore].[NonActivityEvents]  WITH CHECK ADD  CONSTRAINT [FK_NonActivityEvents_Identities] FOREIGN KEY([MemberIdentityId])
REFERENCES [SCore].[Identities] ([ID])
GO
ALTER TABLE [SCore].[NonActivityEvents] CHECK CONSTRAINT [FK_NonActivityEvents_Identities]
GO
ALTER TABLE [SCore].[Sectors]  WITH CHECK ADD  CONSTRAINT [FK_Sectors_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SCore].[Sectors] CHECK CONSTRAINT [FK_Sectors_DataObjects]
GO
ALTER TABLE [SCore].[Sectors]  WITH CHECK ADD  CONSTRAINT [FK_Sectors_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[Sectors] CHECK CONSTRAINT [FK_Sectors_RowStatus]
GO
ALTER TABLE [SCore].[SequenceTable]  WITH CHECK ADD  CONSTRAINT [FK_SequenceTable_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[SequenceTable] CHECK CONSTRAINT [FK_SequenceTable_RowStatus]
GO
ALTER TABLE [SCore].[SharepointSites]  WITH CHECK ADD  CONSTRAINT [FK_SharepointSites_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[SharepointSites] CHECK CONSTRAINT [FK_SharepointSites_RowStatus]
GO
ALTER TABLE [SCore].[Versioning]  WITH CHECK ADD  CONSTRAINT [FK_Versioning_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SCore].[Versioning] CHECK CONSTRAINT [FK_Versioning_RowStatus]
GO
ALTER TABLE [SCore].[Workflow]  WITH CHECK ADD  CONSTRAINT [FK_Workflow_EntityHoBTs] FOREIGN KEY([EntityHoBTID])
REFERENCES [SCore].[EntityHobts] ([ID])
GO
ALTER TABLE [SCore].[Workflow] CHECK CONSTRAINT [FK_Workflow_EntityHoBTs]
GO
ALTER TABLE [SCore].[Workflow]  WITH CHECK ADD  CONSTRAINT [FK_Workflow_EntityTypes] FOREIGN KEY([EntityTypeID])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SCore].[Workflow] CHECK CONSTRAINT [FK_Workflow_EntityTypes]
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups]  WITH CHECK ADD  CONSTRAINT [FK_WFStatusNotificationGroups_Groups] FOREIGN KEY([GroupID])
REFERENCES [SCore].[Groups] ([ID])
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] CHECK CONSTRAINT [FK_WFStatusNotificationGroups_Groups]
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups]  WITH CHECK ADD  CONSTRAINT [FK_WFStatusNotificationGroups_Workflow] FOREIGN KEY([WorkflowID])
REFERENCES [SCore].[Workflow] ([ID])
GO
ALTER TABLE [SCore].[WorkflowStatusNotificationGroups] CHECK CONSTRAINT [FK_WFStatusNotificationGroups_Workflow]
GO
ALTER TABLE [SCore].[WorkflowTransition]  WITH CHECK ADD  CONSTRAINT [FK_WorkflowTransition_FromStatus] FOREIGN KEY([FromStatusID])
REFERENCES [SCore].[WorkflowStatus] ([ID])
GO
ALTER TABLE [SCore].[WorkflowTransition] CHECK CONSTRAINT [FK_WorkflowTransition_FromStatus]
GO
ALTER TABLE [SCore].[WorkflowTransition]  WITH CHECK ADD  CONSTRAINT [FK_WorkflowTransition_ToStatus] FOREIGN KEY([ToStatusID])
REFERENCES [SCore].[WorkflowStatus] ([ID])
GO
ALTER TABLE [SCore].[WorkflowTransition] CHECK CONSTRAINT [FK_WorkflowTransition_ToStatus]
GO
ALTER TABLE [SCore].[WorkflowTransition]  WITH CHECK ADD  CONSTRAINT [FK_WorkflowTransition_Workflow] FOREIGN KEY([WorkflowID])
REFERENCES [SCore].[Workflow] ([ID])
GO
ALTER TABLE [SCore].[WorkflowTransition] CHECK CONSTRAINT [FK_WorkflowTransition_Workflow]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems]  WITH NOCHECK ADD  CONSTRAINT [FK_ActionMenuItems_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] CHECK CONSTRAINT [FK_ActionMenuItems_DataObjects]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems]  WITH NOCHECK ADD  CONSTRAINT [FK_ActionMenuItems_EntityQueries] FOREIGN KEY([EntityQueryId])
REFERENCES [SCore].[EntityQueries] ([ID])
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] CHECK CONSTRAINT [FK_ActionMenuItems_EntityQueries]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems]  WITH NOCHECK ADD  CONSTRAINT [FK_ActionMenuItems_EntityTypes] FOREIGN KEY([EntityTypeId])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] CHECK CONSTRAINT [FK_ActionMenuItems_EntityTypes]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems]  WITH NOCHECK ADD  CONSTRAINT [FK_ActionMenuItems_LanguageLabels] FOREIGN KEY([LanguageLabelId])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] CHECK CONSTRAINT [FK_ActionMenuItems_LanguageLabels]
GO
ALTER TABLE [SUserInterface].[ActionMenuItems]  WITH NOCHECK ADD  CONSTRAINT [FK_ActionMenuItems_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[ActionMenuItems] CHECK CONSTRAINT [FK_ActionMenuItems_RowStatus]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_DropDownListDefinitions_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] CHECK CONSTRAINT [FK_DropDownListDefinitions_DataObjects]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_DropDownListDefinitions_EntityTypes] FOREIGN KEY([EntityTypeId])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] CHECK CONSTRAINT [FK_DropDownListDefinitions_EntityTypes]
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_DropDownListDefinitions_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[DropDownListDefinitions] CHECK CONSTRAINT [FK_DropDownListDefinitions_RowStatus]
GO
ALTER TABLE [SUserInterface].[GridDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridDefinitions_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SUserInterface].[GridDefinitions] CHECK CONSTRAINT [FK_GridDefinitions_DataObjects]
GO
ALTER TABLE [SUserInterface].[GridDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridDefinitions_LanguageLabelId] FOREIGN KEY([LanguageLabelId])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SUserInterface].[GridDefinitions] CHECK CONSTRAINT [FK_GridDefinitions_LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[GridDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridDefinitions_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[GridDefinitions] CHECK CONSTRAINT [FK_GridDefinitions_RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewActions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewActions_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SUserInterface].[GridViewActions] CHECK CONSTRAINT [FK_GridViewActions_DataObjects]
GO
ALTER TABLE [SUserInterface].[GridViewActions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewActions_EntityQueries] FOREIGN KEY([EntityQueryId])
REFERENCES [SCore].[EntityQueries] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewActions] CHECK CONSTRAINT [FK_GridViewActions_EntityQueries]
GO
ALTER TABLE [SUserInterface].[GridViewActions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewActions_GridViewDefinition] FOREIGN KEY([GridViewDefinitionId])
REFERENCES [SUserInterface].[GridViewDefinitions] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SUserInterface].[GridViewActions] CHECK CONSTRAINT [FK_GridViewActions_GridViewDefinition]
GO
ALTER TABLE [SUserInterface].[GridViewActions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewActions_LanguageLabelId] FOREIGN KEY([LanguageLabelId])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewActions] CHECK CONSTRAINT [FK_GridViewActions_LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[GridViewActions]  WITH CHECK ADD  CONSTRAINT [FK_GridViewActions_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewActions] CHECK CONSTRAINT [FK_GridViewActions_RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewColumnDefinition_GridViewDefinition] FOREIGN KEY([GridViewDefinitionId])
REFERENCES [SUserInterface].[GridViewDefinitions] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] CHECK CONSTRAINT [FK_GridViewColumnDefinition_GridViewDefinition]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewColumnDefinitions_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] CHECK CONSTRAINT [FK_GridViewColumnDefinitions_DataObjects]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewColumnDefinitions_LanguageLabelId] FOREIGN KEY([LanguageLabelId])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] CHECK CONSTRAINT [FK_GridViewColumnDefinitions_LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewColumnDefinitions_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewColumnDefinitions] CHECK CONSTRAINT [FK_GridViewColumnDefinitions_RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewDefinition_GridDefinition] FOREIGN KEY([GridDefinitionId])
REFERENCES [SUserInterface].[GridDefinitions] ([ID])
ON DELETE CASCADE
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] CHECK CONSTRAINT [FK_GridViewDefinition_GridDefinition]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewDefinitions_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] CHECK CONSTRAINT [FK_GridViewDefinitions_DataObjects]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewDefinitions_DrawerIconId] FOREIGN KEY([DrawerIconId])
REFERENCES [SUserInterface].[Icons] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] CHECK CONSTRAINT [FK_GridViewDefinitions_DrawerIconId]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewDefinitions_EntityTypes] FOREIGN KEY([EntityTypeID])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] CHECK CONSTRAINT [FK_GridViewDefinitions_EntityTypes]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewDefinitions_LanguageLabelId] FOREIGN KEY([LanguageLabelId])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] CHECK CONSTRAINT [FK_GridViewDefinitions_LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewDefinitions_MetricTypes] FOREIGN KEY([MetricTypeID])
REFERENCES [SUserInterface].[MetricTypes] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] CHECK CONSTRAINT [FK_GridViewDefinitions_MetricTypes]
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewDefinitions_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewDefinitions] CHECK CONSTRAINT [FK_GridViewDefinitions_RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewTypes]  WITH CHECK ADD  CONSTRAINT [FK_GridViewTypes_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewTypes] CHECK CONSTRAINT [FK_GridViewTypes_RowStatus]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewWidgetQueries_EntityQueries] FOREIGN KEY([EntityQueryId])
REFERENCES [SCore].[EntityQueries] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] CHECK CONSTRAINT [FK_GridViewWidgetQueries_EntityQueries]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewWidgetQueries_GridViewDefinitions] FOREIGN KEY([GridViewDefinitionId])
REFERENCES [SUserInterface].[GridViewDefinitions] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] CHECK CONSTRAINT [FK_GridViewWidgetQueries_GridViewDefinitions]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries]  WITH NOCHECK ADD  CONSTRAINT [FK_GridViewWidgetQueries_LanguageLabels] FOREIGN KEY([LanguageLabelID])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] CHECK CONSTRAINT [FK_GridViewWidgetQueries_LanguageLabels]
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries]  WITH CHECK ADD  CONSTRAINT [FK_GridViewWidgetQueries_WidgetTypes] FOREIGN KEY([WidgetTypeId])
REFERENCES [SUserInterface].[WidgetTypes] ([Id])
GO
ALTER TABLE [SUserInterface].[GridViewWidgetQueries] CHECK CONSTRAINT [FK_GridViewWidgetQueries_WidgetTypes]
GO
ALTER TABLE [SUserInterface].[Icons]  WITH CHECK ADD  CONSTRAINT [FK_Icons_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[Icons] CHECK CONSTRAINT [FK_Icons_RowStatus]
GO
ALTER TABLE [SUserInterface].[MainMenuItems]  WITH NOCHECK ADD  CONSTRAINT [FK_MainMenuItems_DataObjects] FOREIGN KEY([Guid])
REFERENCES [SCore].[DataObjects] ([Guid])
GO
ALTER TABLE [SUserInterface].[MainMenuItems] CHECK CONSTRAINT [FK_MainMenuItems_DataObjects]
GO
ALTER TABLE [SUserInterface].[MainMenuItems]  WITH CHECK ADD  CONSTRAINT [FK_MainMenuItems_Icons] FOREIGN KEY([IconId])
REFERENCES [SUserInterface].[Icons] ([ID])
GO
ALTER TABLE [SUserInterface].[MainMenuItems] CHECK CONSTRAINT [FK_MainMenuItems_Icons]
GO
ALTER TABLE [SUserInterface].[MainMenuItems]  WITH NOCHECK ADD  CONSTRAINT [FK_MainMenuItems_LanguageLabelId] FOREIGN KEY([LanguageLabelId])
REFERENCES [SCore].[LanguageLabels] ([ID])
GO
ALTER TABLE [SUserInterface].[MainMenuItems] CHECK CONSTRAINT [FK_MainMenuItems_LanguageLabelId]
GO
ALTER TABLE [SUserInterface].[MainMenuItems]  WITH CHECK ADD  CONSTRAINT [FK_MainMenuItems_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[MainMenuItems] CHECK CONSTRAINT [FK_MainMenuItems_RowStatus]
GO
ALTER TABLE [SUserInterface].[MetricTypes]  WITH CHECK ADD  CONSTRAINT [FK_MetricTypes_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[MetricTypes] CHECK CONSTRAINT [FK_MetricTypes_RowStatus]
GO
ALTER TABLE [SUserInterface].[PropertyGroupLayouts]  WITH CHECK ADD  CONSTRAINT [FK_PropertyGroupLayouts_RowStatus] FOREIGN KEY([RowStatus])
REFERENCES [SCore].[RowStatus] ([ID])
GO
ALTER TABLE [SUserInterface].[PropertyGroupLayouts] CHECK CONSTRAINT [FK_PropertyGroupLayouts_RowStatus]
GO
ALTER TABLE [SUserInterface].[WidgetDashboards]  WITH NOCHECK ADD  CONSTRAINT [FK_WidgetDashboards_EntityTypes] FOREIGN KEY([ParentEntityTypeId])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SUserInterface].[WidgetDashboards] CHECK CONSTRAINT [FK_WidgetDashboards_EntityTypes]
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes]  WITH CHECK ADD  CONSTRAINT [FK_WidgetDashboardWidgetTypes_WidgetDashboards] FOREIGN KEY([WidgetDashboardId])
REFERENCES [SUserInterface].[WidgetDashboards] ([Id])
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] CHECK CONSTRAINT [FK_WidgetDashboardWidgetTypes_WidgetDashboards]
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes]  WITH CHECK ADD  CONSTRAINT [FK_WidgetDashboardWidgetTypes_WidgetTypes] FOREIGN KEY([WidgetTypeId])
REFERENCES [SUserInterface].[WidgetTypes] ([Id])
GO
ALTER TABLE [SUserInterface].[WidgetDashboardWidgetTypes] CHECK CONSTRAINT [FK_WidgetDashboardWidgetTypes_WidgetTypes]
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Describes the type of data stored in an Entity Property' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'EntityDataTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Describes the structural object used for hold the Entity Properties' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'EntityHobts'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Describes the properties within each Entity Type and how they relate to the columns in the HoBT' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'EntityProperties'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'When the parent property changes, which properties should be rebound?' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'EntityPropertyDependants'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Records to group properties together' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'EntityPropertyGroups'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The queries to run in SQL to perform different functions on this Entity Type e.g. Create Read Update Delete Validate' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'EntityQueries'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'How to map the values of the Entity Properties to the Parameters of the Entity Query' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'EntityQueryParameters'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The definition of a thing in the system e.g. Job or Quote.' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'EntityTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Kafka notification source identifier (e.g. cymbuild-fireengineering-authorisation)' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'Groups', @level2type=N'COLUMN',@level2name=N'Source'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Groups of Users' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'Groups'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Labels to put against properties in the UI.' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'LanguageLabels'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Language translations for the Language Labels' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'LanguageLabelTranslations'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'A List of Languages to be used with Language Labels' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'Languages'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The definitions of Merge Documents ' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'MergeDocuments'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The definitions of Talbes for Merge Documents ' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'MergeDocumentTables'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'An Enum of possible RowStatus Values. Used to maintain the integrity of the RowStatus column on all tables. ' , @level0type=N'SCHEMA',@level0name=N'SCore', @level1type=N'TABLE',@level1name=N'RowStatus'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'Definition of actions to display in the Tasks Menu for an Entity Type' , @level0type=N'SCHEMA',@level0name=N'SUserInterface', @level1type=N'TABLE',@level1name=N'ActionMenuItems'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The definition of how to display a drop down list. ' , @level0type=N'SCHEMA',@level0name=N'SUserInterface', @level1type=N'TABLE',@level1name=N'DropDownListDefinitions'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The definition of Grid layouts that are the parent container of GridViewDefinitions' , @level0type=N'SCHEMA',@level0name=N'SUserInterface', @level1type=N'TABLE',@level1name=N'GridDefinitions'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The definition of the columns that make up a Grid View' , @level0type=N'SCHEMA',@level0name=N'SUserInterface', @level1type=N'TABLE',@level1name=N'GridViewColumnDefinitions'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The definition of Grid Views, these are children of GridDefinitions and contain GridViewColumnDefinitions' , @level0type=N'SCHEMA',@level0name=N'SUserInterface', @level1type=N'TABLE',@level1name=N'GridViewDefinitions'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The types of gauges that can be shown on the dashboard.' , @level0type=N'SCHEMA',@level0name=N'SUserInterface', @level1type=N'TABLE',@level1name=N'Icons'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The types of gauges that can be shown on the dashboard.' , @level0type=N'SCHEMA',@level0name=N'SUserInterface', @level1type=N'TABLE',@level1name=N'MetricTypes'
GO
EXEC sys.sp_addextendedproperty @name=N'MS_Description', @value=N'The options for how Property Groups are displayed e.g. Row or Column ' , @level0type=N'SCHEMA',@level0name=N'SUserInterface', @level1type=N'TABLE',@level1name=N'PropertyGroupLayouts'
GO
