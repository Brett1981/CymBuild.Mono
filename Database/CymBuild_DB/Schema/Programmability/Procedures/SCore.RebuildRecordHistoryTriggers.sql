SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[RebuildRecordHistoryTriggers]
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
			@MainHobtName NVARCHAR(250)

	DECLARE	@HoBTs TABLE 
	(
		ID BIGINT IDENTITY(1,1) PRIMARY KEY,
		SchemaName NVARCHAR(250),
		TableName NVARCHAR(250),
		PrimaryKeyColumn NVARCHAR(254),
		HobtId INT,
		EntityTypeId INT,
		IsMainTable BIT
	)

	DECLARE	@Columns TABLE 
	(
		ID BIGINT IDENTITY(1,1) PRIMARY KEY,
		ColumnName NVARCHAR(250),
		EntityPropertyId INT
	)

	INSERT @HoBTs
		 (SchemaName, TableName, PrimaryKeyColumn, HobtID, EntityTypeID, IsMainTable)
	SELECT	h.SchemaName, h.ObjectName, N'ID', h.ID, h.EntityTypeID, h.IsMainHoBT
	FROM	SCore.EntityHobts h
	JOIN	SCore.EntityTypes et ON (et.ID = h.EntityTypeID)
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
				@EntityTypeId = EntityTypeId
		FROM	@HoBTs
		WHERE	(ID > @CurrentTableID)
		ORDER BY ID

		PRINT @TableName

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
		WHERE	(ep.EntityHoBTID = @HobtId)
			AND	(ep.RowStatus NOT IN (0, 254))
			AND	(ep.IsVirtual = 0)
			AND	(ep.DoNotTrackChanges = 0)
			AND	(ep.name NOT IN (N'RowVersion'))

        -- Drop the trigger if it alread exists 
		IF (EXISTS (SELECT 1 FROM sys.triggers WHERE (name = N'tg_' + @TableName + N'_RecordHistory')))
		BEGIN 
			SET @stmt = N'DROP TRIGGER ' + @SchemaName + N'.[tg_' + @TableName +  N'_RecordHistory]'			

			EXEC sp_executesql @stmt
		END

		SET @stmt = N'CREATE TRIGGER '+ @SchemaName + N'.[tg_' + @TableName + N'_RecordHistory]
   ON  ' + @SchemaName + N'.[' + @TableName + N']	
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

	SELECT	@MaxInsertedID = MAX([' + @PrimaryKeyColumn + ']),
			@CurrentInsertedID = -1
	FROM	Inserted

	WHILE	(@CurrentInsertedID < @MaxInsertedID)
	BEGIN '

	IF (@IsMainTable = 1)  
	BEGIN 

		SET @stmt = @stmt + N'
		SELECT	TOP(1) @CurrentInsertedID = i.[' + @PrimaryKeyColumn + '],
				@CurrentInsertedGuid = i.Guid
		FROM	Inserted i
		WHERE	(i.[' + @PrimaryKeyColumn + '] > @CurrentInsertedID)
			ORDER BY i.[' + @PrimaryKeyColumn + ']
		
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
		SELECT	TOP(1) @CurrentInsertedID = i.[' + @PrimaryKeyColumn + ']
		FROM	Inserted i
		WHERE	(i.[' + @PrimaryKeyColumn + '] > @CurrentInsertedID)
			ORDER BY i.[' + @PrimaryKeyColumn + ']

		SELECT	TOP(1) @CurrentInsertedGuid = i.Guid
		FROM	[' + @MainHobtSchema + '].[' + @MainHobtName + '] i
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
                WHERE	(i.[' + @PrimaryKeyColumn + '] = @CurrentInsertedID)   
            END
            
            '
        END

		SET @stmt = @stmt + N'
		
		IF (NOT EXISTS 
				(
					SELECT	1
					FROM 	deleted d
					WHERE	(d.[' + @PrimaryKeyColumn + '] = @CurrentInsertedID)
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

			SET @stmt = @stmt +
			N'SELECT	
					@PreviousValue = ISNULL(CONVERT(NVARCHAR(max), d.[' + @ColumnName + ']), N''''),
					@NewValue = ISNULL(CONVERT(NVARCHAR(max), i.[' + @ColumnName + ']), N'''')
			FROM	Inserted i
			JOIN	Deleted d ON (i.[' + @PrimaryKeyColumn + '] = d.[' + @PrimaryKeyColumn + '])
			WHERE	(i.[' + @PrimaryKeyColumn + '] = @CurrentInsertedID)
                AND (d.[' + @ColumnName + '] IS DISTINCT FROM i.[' + @ColumnName + '])


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

		EXECUTE sp_executesql @stmt
	END
	
END
GO