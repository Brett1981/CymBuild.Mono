SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[CreateDefaultRows]
AS
BEGIN
	
	EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
									@value = 1;

    DECLARE @Tables TABLE 
    (
        ID int identity(1,1),
        SchemaName nvarchar(254) null,
        TableName nvarchar(254) null
    )
            
            
    DECLARE @Exists bit,
			@Incorrect BIT,
            @MaxTableID int,
            @CurrentTableID int = -1,
            @stmt NVARCHAR(2550),
            @CurrentSchemaName nvarchar(254),
            @CurrentTableName nvarchar(254)
            

    INSERT @Tables (SchemaName, TableName)
    SELECT SCHEMA_NAME(t.Schema_id), t.Name
    FROM sys.tables t
	WHERE (EXISTS 
			(
				SELECT	1
				FROM	sys.columns c 
				WHERE	(c.object_id = t.object_id)
					AND	(c.Name = N'Guid')
			)
		)
	AND (EXISTS 
			(
				SELECT	1
				FROM	sys.columns c 
				WHERE	(c.object_id = t.object_id)
					AND	(c.is_identity = 1)
			)
		)

    SELECT @MaxTableID = MAX(ID)
    FROM    @Tables

    WHILE (@CurrentTableID < @MaxTableID)
    BEGIN 
        SELECT  TOP(1) @CurrentTableID = ID,
                @Exists = 0,
                @CurrentSchemaName = SchemaName,
                @CurrentTableName = TableName
        FROM    @Tables
        WHERE   (ID > @CurrentTableID)
        ORDER BY ID

        SET @stmt = N'IF (EXISTS (SELECT 1 FROM [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] WHERE (ID = -1))) BEGIN SET @Exists = 1 END'

        exec sp_executesql @stmt, N'@Exists bit OUTPUT', @Exists OUT

        IF (@Exists <> 1)
        BEGIN 
            SET @stmt = N'SET IDENTITY_INSERT [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] ON; INSERT [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] (ID, Guid) VALUES (-1,''00000000-0000-0000-0000-000000000000'' ); SET IDENTITY_INSERT [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] OFF;' 

            exec sp_executesql @stmt
        END

		SET @stmt = N'IF (EXISTS (SELECT 1 FROM [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] WHERE (ID = -1) AND (Guid <> ''00000000-0000-0000-0000-000000000000''))) BEGIN SET @Incorrect = 1 END'

        exec sp_executesql @stmt, N'@Incorrect bit OUTPUT', @Incorrect OUT

        IF (@Incorrect = 1)
        BEGIN 
            SET @stmt = N'UPDATE [' + @CurrentSchemaName + '].[' + @CurrentTableName + '] SET Guid = ''00000000-0000-0000-0000-000000000000'' WHERE (ID = -1);' 

            exec sp_executesql @stmt
        END
    END


	
	EXEC sys.sp_set_session_context @key = 'S_disable_triggers',
									@value = 0;
END

GO