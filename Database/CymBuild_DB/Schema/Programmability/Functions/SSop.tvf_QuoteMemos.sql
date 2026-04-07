SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SSop].[tvf_QuoteMemos]
  (
    @UserId     INT,
    @ParentGuid UNIQUEIDENTIFIER
  )
RETURNS TABLE
   --WITH SCHEMABINDING
AS
  RETURN SELECT
          qm.ID,
          qm.RowStatus,
          qm.RowVersion,
          qm.Guid,
          qm.Memo,
          CONVERT(DATE, qm.CreatedDateTimeUTC) AS CreatedDate,
		  id.FullName 
  FROM
          SSop.QuoteMemos AS qm
  JOIN
          SSop.Quotes AS q ON (q.ID = qm.QuoteID)
  JOIN	  SCore.Identities		AS id ON (id.ID = qm.CreatedByUserId)
  WHERE
          (qm.RowStatus NOT IN (0, 254))
          AND (q.Guid = @ParentGuid)
          AND (EXISTS
          (
              SELECT
                      1
              FROM
                      SCore.ObjectSecurityForUser_CanRead(qm.Guid, @UserId) oscr
          )
          )

GO