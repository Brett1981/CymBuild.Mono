/*
    CYB-361 generated manual preview deployment script
    Target server   : SOC-SQLDEVBRE01\GENERAL
    Target database : CymBuild_QA
    Run Guid        : 338f17d6-e688-48e9-8e5d-30dd30c7f79f
    Generated UTC   : 2026-09-16T09:03:28.4884000Z

    INSPECTION ONLY. Do not execute this generated file as the approved deployment path.
    Run Invoke-CymBuildSchemaDeployment.ps1 so existence checks, LIVE guardrails and SMigration audit are enforced.
*/
USE [CymBuild_QA];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 1, @read_only = 0;
GO
EXEC [SCore].[PreDeploymentScript];
GO
EXEC sys.sp_set_session_context @key = N'CymBuild_schema_predeployment_will_run', @value = 0, @read_only = 0;
GO

/* Deploy Table SCore.MergeDocumentItemGatingProducts using CanonicalCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Tables\SCore.MergeDocumentItemGatingProducts.sql */
PRINT (N'Create table [SCore].[MergeDocumentItemGatingProducts]')
GO
CREATE TABLE [SCore].[MergeDocumentItemGatingProducts] (
  [ID] [int] IDENTITY,
  [Guid] [uniqueidentifier] NOT NULL CONSTRAINT [DF_MergeDocumentItemGatingProducts_Guid] DEFAULT (newid()) ROWGUIDCOL,
  [RowStatus] [tinyint] NOT NULL CONSTRAINT [DF_MergeDocumentItemGatingProducts_RowStatus] DEFAULT (1),
  [RowVersion] [timestamp],
  [MergeDocumentItemId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemGatingProducts_MergeDocumentItemId] DEFAULT (-1),
  [ProductId] [int] NOT NULL CONSTRAINT [DF_MergeDocumentItemGatingProducts_ProductId] DEFAULT (-1)
)
ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_MergeDocumentItemGatingProducts] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK
  ADD CONSTRAINT [PK_MergeDocumentItemGatingProducts] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create index [IX_UQ_MergeDocumentItemGatingProducts_Guid] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItemGatingProducts_Guid]
  ON [SCore].[MergeDocumentItemGatingProducts] ([Guid])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

PRINT (N'Create index [IX_UQ_MergeDocumentItemGatingProducts_Item_Product] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
-- One gating row per (MergeDocumentItem, Product) pair. A row with no gating rows at all is
-- treated as unconditional (always included) by WordDocumentService - see
-- EF.Core.GetGatingProductIdsForMergeDocumentItem and
-- WordDocumentService.ShouldIncludeRowForQuote (CYB-323).
CREATE UNIQUE INDEX [IX_UQ_MergeDocumentItemGatingProducts_Item_Product]
  ON [SCore].[MergeDocumentItemGatingProducts] ([MergeDocumentItemId], [ProductId])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create trigger [tg_MergeDocumentItemGatingProducts_RecordHistory] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
CREATE TRIGGER [SCore].[tg_MergeDocumentItemGatingProducts_RecordHistory]
   ON  [SCore].[MergeDocumentItemGatingProducts]
   AFTER INSERT, UPDATE
AS
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N'S_disable_triggers')), 0) = 1)
    BEGIN
        RETURN
    END

	IF (EXISTS
			(
				SELECT	1
				FROM	Inserted
				WHERE	(ID = -1)
			)
		)
	BEGIN
		;THROW 60000, N'Data integrity exception: Attempt to alter -1 record', 1
	END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N'SCore',
			@TableName NVARCHAR(250) = N'MergeDocumentItemGatingProducts',
			@MaxInsertedID BIGINT,
			@CurrentInsertedID BIGINT,
			@CurrentInsertedGuid UNIQUEIDENTIFIER

	SELECT @UserID = ISNULL(CONVERT(int, SESSION_CONTEXT(N'user_id')), -1)

	SELECT	@MaxInsertedID = MAX([ID]),
			@CurrentInsertedID = -1
	FROM	Inserted

	WHILE	(@CurrentInsertedID < @MaxInsertedID)
	BEGIN
		SELECT	TOP(1) @CurrentInsertedID = i.[ID],
				@CurrentInsertedGuid = i.Guid
		FROM	Inserted i
		WHERE	(i.[ID] > @CurrentInsertedID)
			ORDER BY i.[ID]

		IF (NOT EXISTS
				(
					SELECT	1
					FROM 	deleted d
					WHERE	(d.[ID] = @CurrentInsertedID)
				)
			)
		BEGIN

				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, N'', N'', SYSTEM_USER, -1)

			CONTINUE
		END

			SELECT
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[MergeDocumentItemId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[MergeDocumentItemId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[MergeDocumentItemId] IS DISTINCT FROM i.[MergeDocumentItemId])

			IF (@@RowCount > 0)
			BEGIN
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'MergeDocumentItemId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, -1)
			END

			SELECT
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[ProductId]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[ProductId]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[ProductId] IS DISTINCT FROM i.[ProductId])

			IF (@@RowCount > 0)
			BEGIN
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'ProductId', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, -1)
			END

			SELECT
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[RowStatus]), N''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[RowStatus]), N'')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[ID] = d.[ID])
			WHERE	(i.[ID] = @CurrentInsertedID)
                AND (d.[RowStatus] IS DISTINCT FROM i.[RowStatus])

			IF (@@RowCount > 0)
			BEGIN
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'RowStatus', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, -1)
			END

	END
END
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemGatingProducts_MergeDocumentItems] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_MergeDocumentItems] FOREIGN KEY ([MergeDocumentItemId]) REFERENCES [SCore].[MergeDocumentItems] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemGatingProducts_Products] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID])
GO

PRINT (N'Create foreign key [FK_MergeDocumentItemGatingProducts_RowStatus] on table [SCore].[MergeDocumentItemGatingProducts]')
GO
ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK
  ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID])
GO

GO

/* Deploy Table SCore.SchemaDeploymentFullTextCapture using CanonicalCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Tables\SCore.SchemaDeploymentFullTextCapture.sql */
PRINT (N'Create table [SCore].[SchemaDeploymentFullTextCapture]')
GO
CREATE TABLE [SCore].[SchemaDeploymentFullTextCapture] (
  [ID] [int] IDENTITY,
  [ComparisonGuid] [uniqueidentifier] NOT NULL,
  [SchemaName] [sysname] NOT NULL,
  [TableName] [sysname] NOT NULL,
  [ConstraintName] [sysname] NOT NULL,
  [CatalogName] [sysname] NULL,
  [ChangeTrackingState] [nvarchar](20) NOT NULL,
  [StopListClause] [nvarchar](300) NOT NULL,
  [ColumnsClause] [nvarchar](max) NOT NULL,
  [CapturedUtc] [datetime2] NOT NULL CONSTRAINT [DF_SchemaDeploymentFullTextCapture_CapturedUtc] DEFAULT (sysutcdatetime())
)
ON [PRIMARY]
TEXTIMAGE_ON [PRIMARY]
GO

PRINT (N'Create primary key [PK_SchemaDeploymentFullTextCapture] on table [SCore].[SchemaDeploymentFullTextCapture]')
GO
ALTER TABLE [SCore].[SchemaDeploymentFullTextCapture] WITH NOCHECK
  ADD CONSTRAINT [PK_SchemaDeploymentFullTextCapture] PRIMARY KEY CLUSTERED ([ID]) WITH (FILLFACTOR = 80)
GO

PRINT (N'Create unique index [IX_UQ_SchemaDeploymentFullTextCapture_Table] on table [SCore].[SchemaDeploymentFullTextCapture]')
GO
CREATE UNIQUE INDEX [IX_UQ_SchemaDeploymentFullTextCapture_Table]
  ON [SCore].[SchemaDeploymentFullTextCapture] ([SchemaName], [TableName])
  WITH (FILLFACTOR = 80)
  ON [PRIMARY]
GO

GO

/* Post-structure preflight Constraint SCore.DF_SCore_MergeDocumentItemGatingProducts_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_Guid deployed as DF_MergeDocumentItemGatingProducts_Guid
    Difference         : MissingInTarget
    Comparison hash    : 3E2139BB71C00FC36F355E40C61FF5C87B244A8552D2D5D0B93B10DF1A8A7D90
    Definition SHA-256 : 5466C2DEBCC1CEBCB643F089A3068661BE36396D416584489103BCD38CF76CA5
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.MergeDocumentItemGatingProducts does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'Guid') IS NULL
    THROW 51404, 'Default-constraint column SCore.MergeDocumentItemGatingProducts.Guid does not exist.', 1;
IF OBJECT_ID(N'[SCore].[DF_MergeDocumentItemGatingProducts_Guid]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SCore].[DF_MergeDocumentItemGatingProducts_Guid]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND c.name = N'Guid') THROW 51422, 'Default constraint name SCore.DF_MergeDocumentItemGatingProducts_Guid is already used by another column.', 1;
IF EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND c.name = N'Guid' AND dc.name <> N'DF_MergeDocumentItemGatingProducts_Guid') THROW 51423, 'Default-constraint column SCore.MergeDocumentItemGatingProducts.Guid already has a different constraint.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.DF_SCore_MergeDocumentItemGatingProducts_MergeDocumentItemId */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_MergeDocumentItemId deployed as DF_MergeDocumentItemGatingProducts_MergeDocumentItemId
    Difference         : MissingInTarget
    Comparison hash    : 5C9983094C5F4BC3CA45B7E481B6E036B2B1C19FFB688FF22CFA3A4200688C10
    Definition SHA-256 : 5E0059692927550A0A99E9D4693597047C33E7AD911321C4C9BAF30CC2221600
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.MergeDocumentItemGatingProducts does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'MergeDocumentItemId') IS NULL
    THROW 51404, 'Default-constraint column SCore.MergeDocumentItemGatingProducts.MergeDocumentItemId does not exist.', 1;
IF OBJECT_ID(N'[SCore].[DF_MergeDocumentItemGatingProducts_MergeDocumentItemId]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SCore].[DF_MergeDocumentItemGatingProducts_MergeDocumentItemId]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND c.name = N'MergeDocumentItemId') THROW 51422, 'Default constraint name SCore.DF_MergeDocumentItemGatingProducts_MergeDocumentItemId is already used by another column.', 1;
IF EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND c.name = N'MergeDocumentItemId' AND dc.name <> N'DF_MergeDocumentItemGatingProducts_MergeDocumentItemId') THROW 51423, 'Default-constraint column SCore.MergeDocumentItemGatingProducts.MergeDocumentItemId already has a different constraint.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.DF_SCore_MergeDocumentItemGatingProducts_ProductId */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_ProductId deployed as DF_MergeDocumentItemGatingProducts_ProductId
    Difference         : MissingInTarget
    Comparison hash    : 297AAA72C313747A0743222A8A4749DAC13F011B964E14C356600C450536079C
    Definition SHA-256 : ABC652983A46C89359CC0DD13AF0C38916D896219691578B14E946992B3C2FB0
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.MergeDocumentItemGatingProducts does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'ProductId') IS NULL
    THROW 51404, 'Default-constraint column SCore.MergeDocumentItemGatingProducts.ProductId does not exist.', 1;
IF OBJECT_ID(N'[SCore].[DF_MergeDocumentItemGatingProducts_ProductId]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SCore].[DF_MergeDocumentItemGatingProducts_ProductId]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND c.name = N'ProductId') THROW 51422, 'Default constraint name SCore.DF_MergeDocumentItemGatingProducts_ProductId is already used by another column.', 1;
IF EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND c.name = N'ProductId' AND dc.name <> N'DF_MergeDocumentItemGatingProducts_ProductId') THROW 51423, 'Default-constraint column SCore.MergeDocumentItemGatingProducts.ProductId already has a different constraint.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.DF_SCore_MergeDocumentItemGatingProducts_RowStatus */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_RowStatus deployed as DF_MergeDocumentItemGatingProducts_RowStatus
    Difference         : MissingInTarget
    Comparison hash    : 3287B1D0DFE6FE72DA4395874C0730BE838DFFB37322A5A28FD2BDC06303341B
    Definition SHA-256 : DA8CC185CB83886229C3AE9580CE83BD6D4CA35516C7DCC387557CEC9FBFDD29
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.MergeDocumentItemGatingProducts does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'RowStatus') IS NULL
    THROW 51404, 'Default-constraint column SCore.MergeDocumentItemGatingProducts.RowStatus does not exist.', 1;
IF OBJECT_ID(N'[SCore].[DF_MergeDocumentItemGatingProducts_RowStatus]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SCore].[DF_MergeDocumentItemGatingProducts_RowStatus]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND c.name = N'RowStatus') THROW 51422, 'Default constraint name SCore.DF_MergeDocumentItemGatingProducts_RowStatus is already used by another column.', 1;
IF EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND c.name = N'RowStatus' AND dc.name <> N'DF_MergeDocumentItemGatingProducts_RowStatus') THROW 51423, 'Default-constraint column SCore.MergeDocumentItemGatingProducts.RowStatus already has a different constraint.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.DF_SCore_SchemaDeploymentFullTextCapture_CapturedUtc */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.SchemaDeploymentFullTextCapture.DF_SCore_SchemaDeploymentFullTextCapture_CapturedUtc deployed as DF_SchemaDeploymentFullTextCapture_CapturedUtc
    Difference         : MissingInTarget
    Comparison hash    : DAC90B55405D5C2D36EFA0F78A65E41A0CC4A0413BBEED2396C8453C56E4CB09
    Definition SHA-256 : BEE744166B5AA39CD204D9A48683BDFD79A3FB7A133EA9502AEA43F398F0E67A
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.SchemaDeploymentFullTextCapture does not exist.', 1;
IF COL_LENGTH(N'[SCore].[SchemaDeploymentFullTextCapture]', N'CapturedUtc') IS NULL
    THROW 51404, 'Default-constraint column SCore.SchemaDeploymentFullTextCapture.CapturedUtc does not exist.', 1;
IF OBJECT_ID(N'[SCore].[DF_SchemaDeploymentFullTextCapture_CapturedUtc]', N'D') IS NOT NULL AND NOT EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.object_id = OBJECT_ID(N'[SCore].[DF_SchemaDeploymentFullTextCapture_CapturedUtc]', N'D') AND dc.parent_object_id = OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U') AND c.name = N'CapturedUtc') THROW 51422, 'Default constraint name SCore.DF_SchemaDeploymentFullTextCapture_CapturedUtc is already used by another column.', 1;
IF EXISTS (SELECT 1 FROM sys.default_constraints AS dc INNER JOIN sys.columns AS c ON c.object_id = dc.parent_object_id AND c.column_id = dc.parent_column_id WHERE dc.parent_object_id = OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U') AND c.name = N'CapturedUtc' AND dc.name <> N'DF_SchemaDeploymentFullTextCapture_CapturedUtc') THROW 51423, 'Default-constraint column SCore.SchemaDeploymentFullTextCapture.CapturedUtc already has a different constraint.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.FK_MergeDocumentItemGatingProducts_MergeDocumentItems */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_MergeDocumentItems
    Difference         : MissingInTarget
    Comparison hash    : 97550A0FA7C9CA94F5346D0F2C83E3DDC6E3DD7259C92B6FF089C77D86863EB0
    Definition SHA-256 : D2A5D87358A01CBA8F7C7BBE2F73109925211157C351DF2DCEE224524789DBB3
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.MergeDocumentItemGatingProducts does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'MergeDocumentItemId') IS NULL
    THROW 51401, 'Foreign-key parent column SCore.MergeDocumentItemGatingProducts.MergeDocumentItemId does not exist.', 1;
IF OBJECT_ID(N'[SCore].[MergeDocumentItems]', N'U') IS NULL
    THROW 51402, 'Foreign-key referenced table SCore.MergeDocumentItems does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItems]', N'ID') IS NULL
    THROW 51403, 'Foreign-key referenced column SCore.MergeDocumentItems.ID does not exist.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.FK_MergeDocumentItemGatingProducts_Products */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_Products
    Difference         : MissingInTarget
    Comparison hash    : ECE69AA2441A66216A179FB10C4C2823F9DEA66CB06ADDB7762EECD8AD7B5743
    Definition SHA-256 : C65B029AC6AFF4A56BE870F2B7338324CE74D55BA69FB2795B3EDC6C2E3E88AE
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.MergeDocumentItemGatingProducts does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'ProductId') IS NULL
    THROW 51401, 'Foreign-key parent column SCore.MergeDocumentItemGatingProducts.ProductId does not exist.', 1;
IF OBJECT_ID(N'[SProd].[Products]', N'U') IS NULL
    THROW 51402, 'Foreign-key referenced table SProd.Products does not exist.', 1;
IF COL_LENGTH(N'[SProd].[Products]', N'ID') IS NULL
    THROW 51403, 'Foreign-key referenced column SProd.Products.ID does not exist.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.FK_MergeDocumentItemGatingProducts_RowStatus */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_RowStatus
    Difference         : MissingInTarget
    Comparison hash    : 8A904A5CF3F53015BF49D9A6E81102C32F292845BA06DB6BF29F2F3D3911340F
    Definition SHA-256 : D83939A0BAC6DD455E9751A0DA5CD2F2429CDE108D489DD646B39583F2BCBBD9
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.MergeDocumentItemGatingProducts does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'RowStatus') IS NULL
    THROW 51401, 'Foreign-key parent column SCore.MergeDocumentItemGatingProducts.RowStatus does not exist.', 1;
IF OBJECT_ID(N'[SCore].[RowStatus]', N'U') IS NULL
    THROW 51402, 'Foreign-key referenced table SCore.RowStatus does not exist.', 1;
IF COL_LENGTH(N'[SCore].[RowStatus]', N'ID') IS NULL
    THROW 51403, 'Foreign-key referenced column SCore.RowStatus.ID does not exist.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.PK_MergeDocumentItemGatingProducts */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.PK_MergeDocumentItemGatingProducts
    Difference         : MissingInTarget
    Comparison hash    : 0FC3DC5BAE467DAFB92054560F9677E444075C4B178321C3FE5FFE0F76A5578D
    Definition SHA-256 : A6218FB845BD8D4B83B5B3E1DD35679D46751BE904F234968228B6CE216714C4
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.MergeDocumentItemGatingProducts does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'ID') IS NULL
    THROW 51405, 'Key-constraint column SCore.MergeDocumentItemGatingProducts.ID does not exist.', 1;
IF EXISTS (SELECT 1 FROM [SCore].[MergeDocumentItemGatingProducts] WHERE [ID] IS NULL)
    THROW 51406, 'PRIMARY KEY constraint PK_MergeDocumentItemGatingProducts cannot be created because NULL key values exist.', 1;
IF EXISTS (SELECT [ID] FROM [SCore].[MergeDocumentItemGatingProducts] GROUP BY [ID] HAVING COUNT_BIG(1) > 1)
    THROW 51407, 'Key constraint PK_MergeDocumentItemGatingProducts cannot be created because duplicate key values exist.', 1;
GO

GO

/* Post-structure preflight Constraint SCore.PK_SchemaDeploymentFullTextCapture */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.SchemaDeploymentFullTextCapture.PK_SchemaDeploymentFullTextCapture
    Difference         : MissingInTarget
    Comparison hash    : 0FC3DC5BAE467DAFB92054560F9677E444075C4B178321C3FE5FFE0F76A5578D
    Definition SHA-256 : A6218FB845BD8D4B83B5B3E1DD35679D46751BE904F234968228B6CE216714C4
    Purpose            : Read-only preflight for the selected constraint operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;

IF OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U') IS NULL
    THROW 51400, 'Constraint parent table SCore.SchemaDeploymentFullTextCapture does not exist.', 1;
IF COL_LENGTH(N'[SCore].[SchemaDeploymentFullTextCapture]', N'ID') IS NULL
    THROW 51405, 'Key-constraint column SCore.SchemaDeploymentFullTextCapture.ID does not exist.', 1;
IF EXISTS (SELECT 1 FROM [SCore].[SchemaDeploymentFullTextCapture] WHERE [ID] IS NULL)
    THROW 51406, 'PRIMARY KEY constraint PK_SchemaDeploymentFullTextCapture cannot be created because NULL key values exist.', 1;
IF EXISTS (SELECT [ID] FROM [SCore].[SchemaDeploymentFullTextCapture] GROUP BY [ID] HAVING COUNT_BIG(1) > 1)
    THROW 51407, 'Key constraint PK_SchemaDeploymentFullTextCapture cannot be created because duplicate key values exist.', 1;
GO

GO

/* Post-structure preflight Index SCore.EntityQueries.IX_UQ_EntityQueries_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.EntityQueries.IX_UQ_EntityQueries_Guid
    Difference         : MissingInTarget
    Comparison hash    : 135A5EE34ED377C3CECAACEB411D41EDE8D4AF395ADA9A395A81F01E561F8434
    Definition SHA-256 : 2276445EEBFC07710A34FCDD08B56A0EA999F8982497CD07F58EDF337880384F
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SCore].[EntityQueries]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SCore].[EntityQueries]', N'Guid') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'METADATA') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Guid] FROM [SCore].[EntityQueries] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SCore.EntityQueryParameters.IX_UQ_EntityQueryParameters_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.EntityQueryParameters.IX_UQ_EntityQueryParameters_Guid
    Difference         : MissingInTarget
    Comparison hash    : 022614AE06FF1F34A0D10CA2D6C6DDFCCAEECD19C4369FA93519E42C91978C20
    Definition SHA-256 : 36F909B744E6E9506D8932F55197CF013CE91D091A70F2DA668F09132B9A7550
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SCore].[EntityQueryParameters]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SCore].[EntityQueryParameters]', N'Guid') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'PRIMARY') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Guid] FROM [SCore].[EntityQueryParameters] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Guid */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Guid
    Difference         : MissingInTarget
    Comparison hash    : FF67A7A8E50719E122157A9CEEE401B8976DFE95AC4DE2299F0D00715F2B1F7C
    Definition SHA-256 : 4F626878B7D8EDE387CFB280566DF9F82E6582042D0A655272176EB2888B61EC
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'Guid') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'PRIMARY') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [Guid] FROM [SCore].[MergeDocumentItemGatingProducts] GROUP BY [Guid] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Item_Product */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Item_Product
    Difference         : MissingInTarget
    Comparison hash    : 84DE64F617CE51C75A8CC3DEC4D22E06D88E27B634E952A085C0802FEFE73EC4
    Definition SHA-256 : 156218FE5F7F4D9F046046CD270B414711F93047FF50D73C65677F0506AC4107
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'MergeDocumentItemId') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF COL_LENGTH(N'[SCore].[MergeDocumentItemGatingProducts]', N'ProductId') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'PRIMARY') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [MergeDocumentItemId], [ProductId] FROM [SCore].[MergeDocumentItemGatingProducts] GROUP BY [MergeDocumentItemId], [ProductId] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Post-structure preflight Index SCore.SchemaDeploymentFullTextCapture.IX_UQ_SchemaDeploymentFullTextCapture_Table */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.SchemaDeploymentFullTextCapture.IX_UQ_SchemaDeploymentFullTextCapture_Table
    Difference         : MissingInTarget
    Comparison hash    : 094088A4CAF4E6CED82189EAEEE02376D3E9A829AAF2C3EFC2803F34AEA1FE5E
    Definition SHA-256 : A8BAFA5F6953A6CA2BDA6197A6E2925545CE90437AA6F91E9560B395DF7E222B
    Purpose            : Read-only preflight for the selected index operation.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
IF OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U') IS NULL THROW 51430, 'Index parent table does not exist.', 1;
IF COL_LENGTH(N'[SCore].[SchemaDeploymentFullTextCapture]', N'SchemaName') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF COL_LENGTH(N'[SCore].[SchemaDeploymentFullTextCapture]', N'TableName') IS NULL THROW 51431, 'Index column does not exist.', 1;
IF NOT EXISTS (SELECT 1 FROM sys.data_spaces AS ds WHERE ds.[name] = N'PRIMARY') THROW 51432, 'Index data space does not exist in the target.', 1;
IF EXISTS (SELECT [SchemaName], [TableName] FROM [SCore].[SchemaDeploymentFullTextCapture] GROUP BY [SchemaName], [TableName] HAVING COUNT_BIG(1) > 1) THROW 51433, 'Unique index contains duplicate source key values.', 1;
GO

GO

/* Deploy Index SCore.EntityQueries.IX_UQ_EntityQueries_Guid using IndexCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SCore.EntityQueries.IX_UQ_EntityQueries_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.EntityQueries.IX_UQ_EntityQueries_Guid
    Difference         : MissingInTarget
    Comparison hash    : 135A5EE34ED377C3CECAACEB411D41EDE8D4AF395ADA9A395A81F01E561F8434
    Definition SHA-256 : 2276445EEBFC07710A34FCDD08B56A0EA999F8982497CD07F58EDF337880384F
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[SCore].[EntityQueries]', N'U') AND name = N'IX_UQ_EntityQueries_Guid')
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueries_Guid] ON [SCore].[EntityQueries] ([Guid] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 80, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [METADATA];
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SCore.EntityQueryParameters.IX_UQ_EntityQueryParameters_Guid using IndexCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SCore.EntityQueryParameters.IX_UQ_EntityQueryParameters_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.EntityQueryParameters.IX_UQ_EntityQueryParameters_Guid
    Difference         : MissingInTarget
    Comparison hash    : 022614AE06FF1F34A0D10CA2D6C6DDFCCAEECD19C4369FA93519E42C91978C20
    Definition SHA-256 : 36F909B744E6E9506D8932F55197CF013CE91D091A70F2DA668F09132B9A7550
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[SCore].[EntityQueryParameters]', N'U') AND name = N'IX_UQ_EntityQueryParameters_Guid')
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_EntityQueryParameters_Guid] ON [SCore].[EntityQueryParameters] ([Guid] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 100, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Guid using IndexCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Guid
    Difference         : MissingInTarget
    Comparison hash    : FF67A7A8E50719E122157A9CEEE401B8976DFE95AC4DE2299F0D00715F2B1F7C
    Definition SHA-256 : 4F626878B7D8EDE387CFB280566DF9F82E6582042D0A655272176EB2888B61EC
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND name = N'IX_UQ_MergeDocumentItemGatingProducts_Guid')
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MergeDocumentItemGatingProducts_Guid] ON [SCore].[MergeDocumentItemGatingProducts] ([Guid] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 80, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Item_Product using IndexCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Item_Product.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.MergeDocumentItemGatingProducts.IX_UQ_MergeDocumentItemGatingProducts_Item_Product
    Difference         : MissingInTarget
    Comparison hash    : 84DE64F617CE51C75A8CC3DEC4D22E06D88E27B634E952A085C0802FEFE73EC4
    Definition SHA-256 : 156218FE5F7F4D9F046046CD270B414711F93047FF50D73C65677F0506AC4107
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U') AND name = N'IX_UQ_MergeDocumentItemGatingProducts_Item_Product')
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_MergeDocumentItemGatingProducts_Item_Product] ON [SCore].[MergeDocumentItemGatingProducts] ([MergeDocumentItemId] ASC, [ProductId] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 80, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Index SCore.SchemaDeploymentFullTextCapture.IX_UQ_SchemaDeploymentFullTextCapture_Table using IndexCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Indexes\SCore.SchemaDeploymentFullTextCapture.IX_UQ_SchemaDeploymentFullTextCapture_Table.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Index SCore.SchemaDeploymentFullTextCapture.IX_UQ_SchemaDeploymentFullTextCapture_Table
    Difference         : MissingInTarget
    Comparison hash    : 094088A4CAF4E6CED82189EAEEE02376D3E9A829AAF2C3EFC2803F34AEA1FE5E
    Definition SHA-256 : A8BAFA5F6953A6CA2BDA6197A6E2925545CE90437AA6F91E9560B395DF7E222B
    Purpose            : Finalize phase: create the source index from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U') AND name = N'IX_UQ_SchemaDeploymentFullTextCapture_Table')
    BEGIN
        CREATE UNIQUE NONCLUSTERED INDEX [IX_UQ_SchemaDeploymentFullTextCapture_Table] ON [SCore].[SchemaDeploymentFullTextCapture] ([SchemaName] ASC, [TableName] ASC) WITH (PAD_INDEX = OFF, FILLFACTOR = 80, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY];
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO

GO

/* Deploy Constraint SCore.PK_MergeDocumentItemGatingProducts using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.MergeDocumentItemGatingProducts.PK_MergeDocumentItemGatingProducts.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.PK_MergeDocumentItemGatingProducts
    Difference         : MissingInTarget
    Comparison hash    : 0FC3DC5BAE467DAFB92054560F9677E444075C4B178321C3FE5FFE0F76A5578D
    Definition SHA-256 : A6218FB845BD8D4B83B5B3E1DD35679D46751BE904F234968228B6CE216714C4
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U')
      AND constraintObject.name = N'PK_MergeDocumentItemGatingProducts'
)
    BEGIN
        ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] ADD CONSTRAINT [PK_MergeDocumentItemGatingProducts] PRIMARY KEY CLUSTERED ([ID] ASC) WITH (PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM [SCore].[SchemaDeploymentFullTextCapture] WHERE [SchemaName] = N'SCore' AND [TableName] = N'MergeDocumentItemGatingProducts')
BEGIN
    DECLARE @CymBuildFullTextCatalogName SYSNAME;
    DECLARE @CymBuildFullTextChangeTracking NVARCHAR(20);
    DECLARE @CymBuildFullTextStopListClause NVARCHAR(300);
    DECLARE @CymBuildFullTextColumnsClause NVARCHAR(MAX);
    DECLARE @CymBuildFullTextCreateSql NVARCHAR(MAX);

    SELECT
        @CymBuildFullTextCatalogName = [CatalogName],
        @CymBuildFullTextChangeTracking = [ChangeTrackingState],
        @CymBuildFullTextStopListClause = [StopListClause],
        @CymBuildFullTextColumnsClause = [ColumnsClause]
    FROM [SCore].[SchemaDeploymentFullTextCapture]
    WHERE [SchemaName] = N'SCore' AND [TableName] = N'MergeDocumentItemGatingProducts';

    IF @CymBuildFullTextColumnsClause IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U'))
    BEGIN
        SET @CymBuildFullTextCreateSql =
            N'CREATE FULLTEXT INDEX ON [SCore].[MergeDocumentItemGatingProducts](' + @CymBuildFullTextColumnsClause
            + N') KEY INDEX [PK_MergeDocumentItemGatingProducts] ON ' + QUOTENAME(@CymBuildFullTextCatalogName)
            + N' WITH CHANGE_TRACKING ' + @CymBuildFullTextChangeTracking
            + N', STOPLIST ' + @CymBuildFullTextStopListClause + N';';
        EXEC sys.sp_executesql @CymBuildFullTextCreateSql;
    END;

    DELETE FROM [SCore].[SchemaDeploymentFullTextCapture] WHERE [SchemaName] = N'SCore' AND [TableName] = N'MergeDocumentItemGatingProducts';
END;
GO

GO

/* Deploy Constraint SCore.PK_SchemaDeploymentFullTextCapture using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.SchemaDeploymentFullTextCapture.PK_SchemaDeploymentFullTextCapture.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.SchemaDeploymentFullTextCapture.PK_SchemaDeploymentFullTextCapture
    Difference         : MissingInTarget
    Comparison hash    : 0FC3DC5BAE467DAFB92054560F9677E444075C4B178321C3FE5FFE0F76A5578D
    Definition SHA-256 : A6218FB845BD8D4B83B5B3E1DD35679D46751BE904F234968228B6CE216714C4
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U')
      AND constraintObject.name = N'PK_SchemaDeploymentFullTextCapture'
)
    BEGIN
        ALTER TABLE [SCore].[SchemaDeploymentFullTextCapture] ADD CONSTRAINT [PK_SchemaDeploymentFullTextCapture] PRIMARY KEY CLUSTERED ([ID] ASC) WITH (PAD_INDEX = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 80) ON [PRIMARY];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
SET NOCOUNT ON;
IF EXISTS (SELECT 1 FROM [SCore].[SchemaDeploymentFullTextCapture] WHERE [SchemaName] = N'SCore' AND [TableName] = N'SchemaDeploymentFullTextCapture')
BEGIN
    DECLARE @CymBuildFullTextCatalogName SYSNAME;
    DECLARE @CymBuildFullTextChangeTracking NVARCHAR(20);
    DECLARE @CymBuildFullTextStopListClause NVARCHAR(300);
    DECLARE @CymBuildFullTextColumnsClause NVARCHAR(MAX);
    DECLARE @CymBuildFullTextCreateSql NVARCHAR(MAX);

    SELECT
        @CymBuildFullTextCatalogName = [CatalogName],
        @CymBuildFullTextChangeTracking = [ChangeTrackingState],
        @CymBuildFullTextStopListClause = [StopListClause],
        @CymBuildFullTextColumnsClause = [ColumnsClause]
    FROM [SCore].[SchemaDeploymentFullTextCapture]
    WHERE [SchemaName] = N'SCore' AND [TableName] = N'SchemaDeploymentFullTextCapture';

    IF @CymBuildFullTextColumnsClause IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM sys.fulltext_indexes WHERE object_id = OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U'))
    BEGIN
        SET @CymBuildFullTextCreateSql =
            N'CREATE FULLTEXT INDEX ON [SCore].[SchemaDeploymentFullTextCapture](' + @CymBuildFullTextColumnsClause
            + N') KEY INDEX [PK_SchemaDeploymentFullTextCapture] ON ' + QUOTENAME(@CymBuildFullTextCatalogName)
            + N' WITH CHANGE_TRACKING ' + @CymBuildFullTextChangeTracking
            + N', STOPLIST ' + @CymBuildFullTextStopListClause + N';';
        EXEC sys.sp_executesql @CymBuildFullTextCreateSql;
    END;

    DELETE FROM [SCore].[SchemaDeploymentFullTextCapture] WHERE [SchemaName] = N'SCore' AND [TableName] = N'SchemaDeploymentFullTextCapture';
END;
GO

GO

/* Deploy Constraint SCore.DF_SCore_MergeDocumentItemGatingProducts_Guid using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_Guid.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_Guid deployed as DF_MergeDocumentItemGatingProducts_Guid
    Difference         : MissingInTarget
    Comparison hash    : 3E2139BB71C00FC36F355E40C61FF5C87B244A8552D2D5D0B93B10DF1A8A7D90
    Definition SHA-256 : 5466C2DEBCC1CEBCB643F089A3068661BE36396D416584489103BCD38CF76CA5
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U')
      AND constraintObject.name = N'DF_MergeDocumentItemGatingProducts_Guid'
)
    BEGIN
        ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] ADD CONSTRAINT [DF_MergeDocumentItemGatingProducts_Guid] DEFAULT (newid()) FOR [Guid];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO

GO

/* Deploy Constraint SCore.DF_SCore_MergeDocumentItemGatingProducts_MergeDocumentItemId using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_MergeDocumentItemId.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_MergeDocumentItemId deployed as DF_MergeDocumentItemGatingProducts_MergeDocumentItemId
    Difference         : MissingInTarget
    Comparison hash    : 5C9983094C5F4BC3CA45B7E481B6E036B2B1C19FFB688FF22CFA3A4200688C10
    Definition SHA-256 : 5E0059692927550A0A99E9D4693597047C33E7AD911321C4C9BAF30CC2221600
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U')
      AND constraintObject.name = N'DF_MergeDocumentItemGatingProducts_MergeDocumentItemId'
)
    BEGIN
        ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] ADD CONSTRAINT [DF_MergeDocumentItemGatingProducts_MergeDocumentItemId] DEFAULT ((-1)) FOR [MergeDocumentItemId];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO

GO

/* Deploy Constraint SCore.DF_SCore_MergeDocumentItemGatingProducts_ProductId using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_ProductId.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_ProductId deployed as DF_MergeDocumentItemGatingProducts_ProductId
    Difference         : MissingInTarget
    Comparison hash    : 297AAA72C313747A0743222A8A4749DAC13F011B964E14C356600C450536079C
    Definition SHA-256 : ABC652983A46C89359CC0DD13AF0C38916D896219691578B14E946992B3C2FB0
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U')
      AND constraintObject.name = N'DF_MergeDocumentItemGatingProducts_ProductId'
)
    BEGIN
        ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] ADD CONSTRAINT [DF_MergeDocumentItemGatingProducts_ProductId] DEFAULT ((-1)) FOR [ProductId];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO

GO

/* Deploy Constraint SCore.DF_SCore_MergeDocumentItemGatingProducts_RowStatus using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_RowStatus.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.DF_SCore_MergeDocumentItemGatingProducts_RowStatus deployed as DF_MergeDocumentItemGatingProducts_RowStatus
    Difference         : MissingInTarget
    Comparison hash    : 3287B1D0DFE6FE72DA4395874C0730BE838DFFB37322A5A28FD2BDC06303341B
    Definition SHA-256 : DA8CC185CB83886229C3AE9580CE83BD6D4CA35516C7DCC387557CEC9FBFDD29
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U')
      AND constraintObject.name = N'DF_MergeDocumentItemGatingProducts_RowStatus'
)
    BEGIN
        ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] ADD CONSTRAINT [DF_MergeDocumentItemGatingProducts_RowStatus] DEFAULT ((1)) FOR [RowStatus];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO

GO

/* Deploy Constraint SCore.DF_SCore_SchemaDeploymentFullTextCapture_CapturedUtc using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.SchemaDeploymentFullTextCapture.DF_SCore_SchemaDeploymentFullTextCapture_CapturedUtc.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.SchemaDeploymentFullTextCapture.DF_SCore_SchemaDeploymentFullTextCapture_CapturedUtc deployed as DF_SchemaDeploymentFullTextCapture_CapturedUtc
    Difference         : MissingInTarget
    Comparison hash    : DAC90B55405D5C2D36EFA0F78A65E41A0CC4A0413BBEED2396C8453C56E4CB09
    Definition SHA-256 : BEE744166B5AA39CD204D9A48683BDFD79A3FB7A133EA9502AEA43F398F0E67A
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[SchemaDeploymentFullTextCapture]', N'U')
      AND constraintObject.name = N'DF_SchemaDeploymentFullTextCapture_CapturedUtc'
)
    BEGIN
        ALTER TABLE [SCore].[SchemaDeploymentFullTextCapture] ADD CONSTRAINT [DF_SchemaDeploymentFullTextCapture_CapturedUtc] DEFAULT (sysutcdatetime()) FOR [CapturedUtc];
    END;

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO

GO

/* Deploy Constraint SCore.FK_MergeDocumentItemGatingProducts_MergeDocumentItems using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_MergeDocumentItems.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_MergeDocumentItems
    Difference         : MissingInTarget
    Comparison hash    : 97550A0FA7C9CA94F5346D0F2C83E3DDC6E3DD7259C92B6FF089C77D86863EB0
    Definition SHA-256 : D2A5D87358A01CBA8F7C7BBE2F73109925211157C351DF2DCEE224524789DBB3
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U')
      AND constraintObject.name = N'FK_MergeDocumentItemGatingProducts_MergeDocumentItems'
)
    BEGIN
        ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_MergeDocumentItems] FOREIGN KEY ([MergeDocumentItemId]) REFERENCES [SCore].[MergeDocumentItems] ([ID]) ON DELETE NO ACTION ON UPDATE NO ACTION;
    END;
    ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] CHECK CONSTRAINT [FK_MergeDocumentItemGatingProducts_MergeDocumentItems];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO

GO

/* Deploy Constraint SCore.FK_MergeDocumentItemGatingProducts_Products using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_Products.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_Products
    Difference         : MissingInTarget
    Comparison hash    : ECE69AA2441A66216A179FB10C4C2823F9DEA66CB06ADDB7762EECD8AD7B5743
    Definition SHA-256 : C65B029AC6AFF4A56BE870F2B7338324CE74D55BA69FB2795B3EDC6C2E3E88AE
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U')
      AND constraintObject.name = N'FK_MergeDocumentItemGatingProducts_Products'
)
    BEGIN
        ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_Products] FOREIGN KEY ([ProductId]) REFERENCES [SProd].[Products] ([ID]) ON DELETE NO ACTION ON UPDATE NO ACTION;
    END;
    ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] CHECK CONSTRAINT [FK_MergeDocumentItemGatingProducts_Products];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO

GO

/* Deploy Constraint SCore.FK_MergeDocumentItemGatingProducts_RowStatus using ConstraintCreate from C:\Users\stephen.brett\source\CymBuild.Monorepo\Database\CymBuild_DB\Schema\Constraints\SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_RowStatus.sql */
/*
    CymBuild generated canonical schema source.
    Generated by       : CYB-361 R7C4 selected DEV schema source sync
    Generator contract : R7D13
    Object             : Constraint SCore.MergeDocumentItemGatingProducts.FK_MergeDocumentItemGatingProducts_RowStatus
    Difference         : MissingInTarget
    Comparison hash    : 8A904A5CF3F53015BF49D9A6E81102C32F292845BA06DB6BF29F2F3D3911340F
    Definition SHA-256 : D83939A0BAC6DD455E9751A0DA5CD2F2429CDE108D489DD646B39583F2BCBBD9
    Purpose            : Finalize phase: create the source constraint from the declarative snapshot.

    This deterministic file was generated from an explicitly selected, validated and accepted
    CymBuild_Dev declarative snapshot. Review and commit it through the normal source-control
    process before promotion. Captured database DDL is never executed directly.
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;

BEGIN TRY
    BEGIN TRANSACTION;

    IF NOT EXISTS
(
    SELECT 1
    FROM sys.objects AS constraintObject
    WHERE constraintObject.parent_object_id = OBJECT_ID(N'[SCore].[MergeDocumentItemGatingProducts]', N'U')
      AND constraintObject.name = N'FK_MergeDocumentItemGatingProducts_RowStatus'
)
    BEGIN
        ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] WITH NOCHECK ADD CONSTRAINT [FK_MergeDocumentItemGatingProducts_RowStatus] FOREIGN KEY ([RowStatus]) REFERENCES [SCore].[RowStatus] ([ID]) ON DELETE NO ACTION ON UPDATE NO ACTION;
    END;
    ALTER TABLE [SCore].[MergeDocumentItemGatingProducts] CHECK CONSTRAINT [FK_MergeDocumentItemGatingProducts_RowStatus];

    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0
        ROLLBACK TRANSACTION;
    THROW;
END CATCH;

GO

GO
DECLARE @CymBuildPostDeploymentRunGuid UNIQUEIDENTIFIER = NEWID();
EXEC [SCore].[PostDeploymentScript] @ThrowOnIssues = 1, @RunGuid = @CymBuildPostDeploymentRunGuid;
GO
