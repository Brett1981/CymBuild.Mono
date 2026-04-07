/****** Object:  Table [SCore].[DataObjects]    Script Date: 02/02/2026 21:40:02 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [SCore].[DataObjects](
	[Guid] [uniqueidentifier] ROWGUIDCOL  NOT NULL,
	[RowStatus] [tinyint] NOT NULL,
	[RowVersion] [timestamp] NOT NULL,
	[EntityTypeId] [int] NOT NULL,
 CONSTRAINT [PK_DataObjects] PRIMARY KEY CLUSTERED 
(
	[Guid] ASC
)WITH (PAD_INDEX = ON, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = OFF, FILLFACTOR = 80, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO
ALTER TABLE [SCore].[DataObjects] ADD  CONSTRAINT [DF_DataObjects_Guid]  DEFAULT (newid()) FOR [Guid]
GO
ALTER TABLE [SCore].[DataObjects] ADD  CONSTRAINT [DF_DataObjects_RowStatus]  DEFAULT ((0)) FOR [RowStatus]
GO
ALTER TABLE [SCore].[DataObjects]  WITH NOCHECK ADD  CONSTRAINT [FK_DataObjects_EntityTypes] FOREIGN KEY([EntityTypeId])
REFERENCES [SCore].[EntityTypes] ([ID])
GO
ALTER TABLE [SCore].[DataObjects] CHECK CONSTRAINT [FK_DataObjects_EntityTypes]
GO
