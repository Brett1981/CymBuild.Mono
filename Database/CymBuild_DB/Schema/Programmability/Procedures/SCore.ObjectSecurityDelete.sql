SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO



CREATE PROCEDURE [SCore].[ObjectSecurityDelete]
  @Guid      UNIQUEIDENTIFIER
AS
  BEGIN
    EXEC SCore.DeleteDataObject
      @Guid = @Guid;

    UPDATE  SCore.ObjectSecurity
    SET     RowStatus = 254
    WHERE   Guid = @Guid
  END;

GO