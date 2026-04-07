SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE PROCEDURE [SCore].[PreDeploymentScript]
AS 
BEGIN 
	-- Disable Schema Binding 
	EXEC SCore.SCHEMABINDING @Apply = 0	-- bit
	
  DECLARE @Maxid     INT,
          @CurrentId INT,
          @stmt      NVARCHAR(4000);

  DECLARE @ForeignKeyStatements TABLE
      (
        id        INT            NOT NULL IDENTITY (1, 1),
        statement NVARCHAR(4000) NOT NULL DEFAULT ''
      )


  INSERT @ForeignKeyStatements
        (
          statement
        )
      SELECT
              N'ALTER TABLE [' + SCHEMA_NAME(po.schema_id) + N'].[' + po.Name + N'] NOCHECK CONSTRAINT [' + fk.Name + ']'
      -- N'ALTER TABLE [' + SCHEMA_NAME(po.schema_id) + N'].[' + po.name + N'] CHECK CONSTRAINT [' + fk.name + ']'
      FROM
              sys.foreign_keys fk
      JOIN
              sys.objects po ON (fk.parent_object_id = po.object_id)
      JOIN
              sys.objects ro ON (fk.referenced_object_id = ro.object_id)
      WHERE
              (ro.Name = N'DataObjects');


  SELECT
          @MaxId     = MAX(ID),
          @CurrentId = -1
  FROM
          @ForeignKeyStatements

  WHILE (@CurrentId < @Maxid)
  BEGIN
    SELECT TOP (1)
            @CurrentID = ID,
            @stmt      = statement
    FROM
            @ForeignKeyStatements
    WHERE
            (ID > @CurrentId)
    ORDER BY
            ID

    EXEC sys.sp_executesql
      @stmt;
  END;
END
GO