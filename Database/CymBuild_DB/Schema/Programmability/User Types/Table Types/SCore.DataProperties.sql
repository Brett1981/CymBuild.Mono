CREATE TYPE [SCore].[DataProperties] AS TABLE (
  [EntityPropertyGuid] [uniqueidentifier] NOT NULL,
  [IsInvalid] [bit] NOT NULL DEFAULT (0),
  [IsEnabled] [bit] NOT NULL DEFAULT (0),
  [IsRestricted] [bit] NOT NULL DEFAULT (0),
  [IsHidden] [bit] NOT NULL DEFAULT (0),
  [StringValue] [nvarchar](max) NULL,
  [DoubleValue] [decimal](18, 2) NULL,
  [IntegerValue] [int] NULL,
  [BigIntValue] [bigint] NULL,
  [BitValue] [bit] NULL,
  [DateTimeValue] [datetime2] NULL,
  PRIMARY KEY CLUSTERED ([EntityPropertyGuid])
)
GO