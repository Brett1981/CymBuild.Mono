SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
 

CREATE PROCEDURE [SUserInterface].[GridViewColumnDefinitionsDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
    EXEC SCore.DeleteDataObject
      @Guid = @Guid;

    UPDATE  SUserInterface.GridViewColumnDefinitions
    SET     RowStatus = 254
    WHERE   Guid = @Guid
  END;

GO