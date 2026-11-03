SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[RebuildRecordHistoryTriggers]')
GO



CREATE OR ALTER PROCEDURE [SCore].[RebuildRecordHistoryTriggers]
(
      @RunGuid UNIQUEIDENTIFIER = NULL
    , @ThrowOnError BIT = 1
)
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE	@MaxTableID BIGINT,
			@CurrentTableID BIGINT,
			@stmt NVARCHAR(MAX),
			@SchemaName NVARCHAR(250),
			@TableName NVARCHAR(250),
			@MaxColumnID BIGINT,
			@CurrentColumnID BIGINT,
			@ColumnName NVARCHAR(250),
			@PrimaryKeyColumn NVARCHAR(254),
			@HobtId INT,
			@EntityPropertyId INT,
			@IsMainTable BIT,
			@EntityTypeId INT,
			@MainHobtSchema NVARCHAR(250),
			@MainHobtName NVARCHAR(250),
			@TableObjectId INT,
			@QuotedSchemaName NVARCHAR(258),
			@QuotedTableName NVARCHAR(258),
			@QuotedPrimaryKeyColumn NVARCHAR(258),
			@QuotedColumnName NVARCHAR(258),
			@TriggerName SYSNAME

	DECLARE	@HoBTs TABLE 
	(
		ID BIGINT IDENTITY(1,1) PRIMARY KEY,
		SchemaName NVARCHAR(250),
		TableName NVARCHAR(250),
		PrimaryKeyColumn NVARCHAR(254),
		HobtId INT,
		EntityTypeId INT,
		IsMainTable BIT,
		TableObjectId INT
	)

	DECLARE	@Columns TABLE 
	(
		ID BIGINT IDENTITY(1,1) PRIMARY KEY,
		ColumnName NVARCHAR(250),
		EntityPropertyId INT
	)

	INSERT @HoBTs
		 (SchemaName, TableName, PrimaryKeyColumn, HobtID, EntityTypeID, IsMainTable, TableObjectId)
	SELECT	h.SchemaName, h.ObjectName, N'ID', h.ID, h.EntityTypeID, h.IsMainHoBT, t.object_id
	FROM	SCore.EntityHobts h
	JOIN	SCore.EntityTypes et ON (et.ID = h.EntityTypeID)
	JOIN	sys.schemas s ON (s.name = h.SchemaName)
	JOIN	sys.tables t ON (t.schema_id = s.schema_id AND t.name = h.ObjectName)
	JOIN	sys.columns idColumn ON (idColumn.object_id = t.object_id AND idColumn.name = N'ID')
	WHERE	(et.DoNotTrackChanges = 0)
		AND	(h.RowStatus NOT IN (0, 254))
		AND	(et.RowStatus NOT IN (0, 254))
		AND (h.ObjectType = N'U')
		AND (et.Id > 0)

	SELECT	@MaxTableID = MAX(ID),
			@CurrentTableID = 0
	FROM	@HoBTs

	-- Rebuild Record History Triggers
	WHILE (@CurrentTableID < @MaxTableID)
	BEGIN 
		SELECT	TOP(1) @CurrentTableID = ID,
				@SchemaName = SchemaName,
				@TableName = TableName,
				@PrimaryKeyColumn = PrimaryKeyColumn,
				@HobtId = HobtId,
				@IsMainTable = IsMainTable,
				@EntityTypeId = EntityTypeId,
				@TableObjectId = TableObjectId
		FROM	@HoBTs
		WHERE	(ID > @CurrentTableID)
		ORDER BY ID

		PRINT @TableName

		SET @QuotedSchemaName = QUOTENAME(@SchemaName)
		SET @QuotedTableName = QUOTENAME(@TableName)
		SET @QuotedPrimaryKeyColumn = QUOTENAME(@PrimaryKeyColumn)
		SET @TriggerName = N'tg_' + @TableName + N'_RecordHistory'

        -- Get a collection of all the columns in the table. 
        DELETE @Columns
		INSERT	@Columns
			(
				ColumnName,
				EntityPropertyId
			)
		SELECT	ep.name, ep.Id
		FROM	SCore.EntityProperties ep
		JOIN	SCore.EntityDataTypes edt ON (edt.ID = ep.EntityDataTypeID)
		JOIN	sys.columns physicalColumn
			ON physicalColumn.object_id = @TableObjectId
		   AND physicalColumn.name = ep.name
		WHERE	(ep.EntityHoBTID = @HobtId)
			AND	(ep.RowStatus NOT IN (0, 254))
			AND	(ep.IsVirtual = 0)
			AND	(ep.DoNotTrackChanges = 0)
			AND	(ep.name NOT IN (N'RowVersion'))

		IF @RunGuid IS NOT NULL
		   AND OBJECT_ID(N'SCore.PostDeploymentRunLog', N'U') IS NOT NULL
		BEGIN 
			INSERT INTO SCore.PostDeploymentRunLog
			(
				  RunGuid
				, StepName
				, ObjectName
				, Severity
				, Message
			)
			SELECT
				  @RunGuid
				, N'Rebuild record history triggers'
				, @QuotedSchemaName + N'.' + @QuotedTableName
				, N'Warning'
				, N'Skipped active EntityProperty '
				  + QUOTENAME(ep.name)
				  + N' because no matching physical table column exists.'
			FROM SCore.EntityProperties ep
			JOIN SCore.EntityDataTypes edt ON (edt.ID = ep.EntityDataTypeID)
			LEFT JOIN sys.columns physicalColumn
				ON physicalColumn.object_id = @TableObjectId
			   AND physicalColumn.name = ep.name
			WHERE ep.EntityHoBTID = @HobtId
			  AND ep.RowStatus NOT IN (0, 254)
			  AND ep.IsVirtual = 0
			  AND ep.DoNotTrackChanges = 0
			  AND ep.name NOT IN (N'RowVersion')
			  AND physicalColumn.column_id IS NULL;
		END

		/*
			CREATE OR ALTER preserves the currently working trigger when the newly
			generated definition cannot compile. The previous DROP/CREATE sequence
			could leave audit history disabled after a metadata/column mismatch.
		*/
		SET @stmt = N'CREATE OR ALTER TRIGGER ' + @QuotedSchemaName + N'.' + QUOTENAME(@TriggerName) + N'
   ON  ' + @QuotedSchemaName + N'.' + @QuotedTableName + N'
   AFTER INSERT, UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    IF (ISNULL(CONVERT(int, SESSION_CONTEXT(N''S_disable_triggers'')), 0) = 1)
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
		;THROW 60000, N''Data integrity exception: Attempt to alter -1 record'', 1
	END

    DECLARE	@PreviousValue NVARCHAR(MAX),
			@NewValue NVARCHAR(MAX),
			@UserID INT = 0,
			@SchemaName NVARCHAR(250) = N''' + @SchemaName + ''',
			@TableName NVARCHAR(250) = N''' + @TableName + ''',
			@ColumnName NVARCHAR(250),
			@MaxInsertedID BIGINT,
			@CurrentInsertedID BIGINT,
			@CurrentInsertedGuid UNIQUEIDENTIFIER

	SELECT @UserID = ISNULL(CONVERT(int, SESSION_CONTEXT(N''user_id'')), -1)

	SELECT	@MaxInsertedID = MAX(' + @QuotedPrimaryKeyColumn + N'),
			@CurrentInsertedID = -1
	FROM	Inserted

	WHILE	(@CurrentInsertedID < @MaxInsertedID)
	BEGIN '

	IF (@IsMainTable = 1)  
	BEGIN 

		SET @stmt = @stmt + N'
		SELECT	TOP(1) @CurrentInsertedID = i.' + @QuotedPrimaryKeyColumn + N',
				@CurrentInsertedGuid = i.Guid
		FROM	Inserted i
		WHERE	(i.' + @QuotedPrimaryKeyColumn + N' > @CurrentInsertedID)
			ORDER BY i.' + @QuotedPrimaryKeyColumn + N'
		
		'
	END 
	ELSE
	BEGIN 
		SELECT	@MainHobtSchema = h.SchemaName,
				@MainHobtName = h.ObjectName
		FROM	SCore.EntityHobts h
		WHERE	(h.IsMainHoBT = 1)
			AND	(h.EntityTypeID = @EntityTypeId)
			AND	(h.RowStatus NOT IN (0, 254))


		SET @stmt = @stmt + N'
		SELECT	TOP(1) @CurrentInsertedID = i.' + @QuotedPrimaryKeyColumn + N'
		FROM	Inserted i
		WHERE	(i.' + @QuotedPrimaryKeyColumn + N' > @CurrentInsertedID)
			ORDER BY i.' + @QuotedPrimaryKeyColumn + N'

		SELECT	TOP(1) @CurrentInsertedGuid = i.Guid
		FROM	' + QUOTENAME(@MainHobtSchema) + N'.' + QUOTENAME(@MainHobtName) + N' i
		WHERE	(ID =  @CurrentInsertedID)
		
		'
	END

		IF (EXISTS (SELECT 1 FROM @Columns WHERE (ColumnName = N'last_updated_by')))
        BEGIN 
            SET @stmt = @stmt + N'-- Get the user from last_updated_by if it wasn''t in the session
            IF (@UserID <= 0)
            BEGIN 
                SELECT  @UserID = ISNULL(i.last_updated_by, -1)
                FROM    Inserted i
                WHERE	(i.' + @QuotedPrimaryKeyColumn + N' = @CurrentInsertedID)
            END
            
            '
        END

		SET @stmt = @stmt + N'
		
		IF (NOT EXISTS 
				(
					SELECT	1
					FROM 	deleted d
					WHERE	(d.' + @QuotedPrimaryKeyColumn + N' = @CurrentInsertedID)
				)
			)
		BEGIN 
				
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N'''', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, N'''', N'''', SYSTEM_USER, -1)
	
			RETURN 
		END
		
		'

		SELECT	@MaxColumnID = MAX(ID),
				@CurrentColumnID = 0
		FROM	@Columns
			
		WHILE (@CurrentColumnID < @MaxColumnID)
		BEGIN 
			SELECT	TOP(1) @CurrentColumnID = ID,
					@ColumnName = ColumnName,
					@EntityPropertyId = EntityPropertyId
			FROM	@Columns 
			WHERE	(id > @CurrentColumnID)
			ORDER BY ID

			SET @QuotedColumnName = QUOTENAME(@ColumnName)

			SET @stmt = @stmt +
			N'SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.' + @QuotedColumnName + N'), N''''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.' + @QuotedColumnName + N'), N'''')
			FROM	Inserted i
			JOIN	Deleted d ON (i.' + @QuotedPrimaryKeyColumn + N' = d.' + @QuotedPrimaryKeyColumn + N')
			WHERE	(i.' + @QuotedPrimaryKeyColumn + N' = @CurrentInsertedID)
                AND (d.' + @QuotedColumnName + N' IS DISTINCT FROM i.' + @QuotedColumnName + N')


			IF (@@RowCount > 0)
			BEGIN 
				INSERT	SCore.RecordHistory
				(
					RowStatus, SchemaName, TableName, ColumnName, RowID, RowGuid, UserID, PreviousValue, NewValue, SQLUser, EntityPropertyID
				)
				VALUES(1, @SchemaName, @TableName, N''' + @ColumnName + N''', @CurrentInsertedID, @CurrentInsertedGuid, @UserID, @PreviousValue, @NewValue, SYSTEM_USER, ' + CONVERT(NVARCHAR(MAX), @EntityPropertyId) + ')
			END 
			
			'

		END

		 SET @stmt = @stmt + N'
			END
		END
		
		'

		--PRINT @stmt

		BEGIN TRY
			EXECUTE sys.sp_executesql @stmt
		END TRY
		BEGIN CATCH
			IF @RunGuid IS NOT NULL
			   AND OBJECT_ID(N'SCore.PostDeploymentRunLog', N'U') IS NOT NULL
			BEGIN
				INSERT INTO SCore.PostDeploymentRunLog
				(
					  RunGuid
					, StepName
					, ObjectName
					, Severity
					, Message
					, ErrorNumber
					, ErrorSeverity
					, ErrorState
					, ErrorLine
					, ErrorProcedure
				)
				VALUES
				(
					  @RunGuid
					, N'Rebuild record history triggers'
					, @QuotedSchemaName + N'.' + QUOTENAME(@TriggerName)
					, N'Error'
					, ERROR_MESSAGE()
					, ERROR_NUMBER()
					, ERROR_SEVERITY()
					, ERROR_STATE()
					, ERROR_LINE()
					, ERROR_PROCEDURE()
				);
			END;

			IF @ThrowOnError = 1
				THROW;
		END CATCH
	END
	
END
GO
