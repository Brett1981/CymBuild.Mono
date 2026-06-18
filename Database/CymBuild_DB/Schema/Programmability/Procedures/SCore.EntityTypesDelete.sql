SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

PRINT (N'Create procedure [SCore].[EntityTypesDelete]')
GO




CREATE PROCEDURE [SCore].[EntityTypesDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
    EXEC SCore.DeleteDataObject
      @Guid = @Guid;

    UPDATE  SCore.EntityTypes
    SET     RowStatus = 254
    WHERE   Guid = @Guid
  END;

GO