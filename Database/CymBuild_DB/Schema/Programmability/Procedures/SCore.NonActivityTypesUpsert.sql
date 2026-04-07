SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SCore].[NonActivityTypesUpsert]
  (
    @Name        NVARCHAR(100),
    @Guid        UNIQUEIDENTIFIER OUT
  )
AS
  BEGIN
    SET NOCOUNT ON;

    DECLARE @IsInsert BIT = 0;

    EXEC SCore.UpsertDataObject
      @Guid       = @Guid,					
      @SchemeName = N'SCore',			
      @ObjectName = N'NonActivityTypes',		
      @IsInsert   = @IsInsert OUTPUT;	

    IF (@IsInsert = 1)
      BEGIN
        INSERT INTO SCore.NonActivityTypes
                  (
                    RowStatus,
                    Guid,
                    Name
                  )
        VALUES
                (
                  1,
                  @Guid,
                  @Name
                );
      END;
    ELSE
      BEGIN
        UPDATE  SCore.NonActivityTypes
        SET     Name = @Name
        WHERE
          (Guid = @Guid);
      END;
  END;
GO