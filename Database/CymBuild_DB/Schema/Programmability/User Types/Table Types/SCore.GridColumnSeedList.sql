CREATE TYPE [SCore].[GridColumnSeedList] AS TABLE (
  [Name] [nvarchar](250) NOT NULL,
  [ColumnOrder] [int] NOT NULL,
  [IsPrimaryKey] [bit] NOT NULL DEFAULT (0),
  [IsHidden] [bit] NOT NULL DEFAULT (0),
  [IsFiltered] [bit] NOT NULL DEFAULT (1),
  [DisplayFormat] [nvarchar](250) NOT NULL DEFAULT (N''),
  [Width] [nvarchar](50) NOT NULL DEFAULT (N'120px'),
  [LabelText] [nvarchar](250) NULL,
  [LabelTextPlural] [nvarchar](250) NULL
)
GO