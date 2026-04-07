CREATE TYPE [SCore].[TwoStringBitIndexedList] AS TABLE (
  [ID] [bigint] IDENTITY,
  [StringValue1] [nvarchar](400) NOT NULL DEFAULT (''),
  [StringValue2] [nvarchar](400) NOT NULL DEFAULT (''),
  [BitValue1] [bit] NOT NULL DEFAULT (0),
  PRIMARY KEY CLUSTERED ([ID])
)
GO