CREATE TYPE [SCore].[ValidationResult] AS TABLE (
  [ID] [int] IDENTITY,
  [TargetGuid] [uniqueidentifier] NOT NULL DEFAULT ('00000000-0000-0000-0000-000000000000'),
  [TargetType] [char](1) NOT NULL DEFAULT (''),
  [IsReadOnly] [bit] NOT NULL DEFAULT (0),
  [IsHidden] [bit] NOT NULL DEFAULT (0),
  [IsInvalid] [bit] NOT NULL DEFAULT (0),
  [IsInformationOnly] [bit] NOT NULL DEFAULT (0),
  [Message] [nvarchar](2000) NOT NULL DEFAULT (''),
  PRIMARY KEY CLUSTERED ([ID])
)
GO