CREATE TYPE [SCore].[TwoStringIndexedList] AS TABLE (
  [ID] [bigint] IDENTITY,
  [StringValue1] [nvarchar](400) NOT NULL DEFAULT (''),
  [StringValue2] [nvarchar](400) NOT NULL DEFAULT (''),
  PRIMARY KEY CLUSTERED ([ID])
)
GO