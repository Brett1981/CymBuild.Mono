SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SFin].[tvf_InvoiceScheduleTriggers]
  (
    @UserId INT
  )
RETURNS TABLE
      --WITH SCHEMABINDING
AS
  RETURN
  SELECT
         ist.ID,
		 ist.RowStatus,
		 ist.RowVersion,
		 ist.Guid,
		 ist.Name
  FROM
          SFin.InvoiceScheduleTrigger AS ist
  WHERE
          (ist.RowStatus NOT IN (0, 254))
		  AND (ist.Guid <> '00000000-0000-0000-0000-000000000000')
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(ist.Guid, @UserId) oscr
          )
          )
GO