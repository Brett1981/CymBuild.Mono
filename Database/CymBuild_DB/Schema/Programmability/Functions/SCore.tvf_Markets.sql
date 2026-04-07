SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO

CREATE FUNCTION [SCore].[tvf_Markets]
  (
    @UserId INT
  )
RETURNS TABLE
	--WITH SCHEMABINDING
AS
  RETURN 
  
  SELECT
          root_hobt.ID,
		  root_hobt.Guid,
		  root_hobt.RowVersion,
		  root_hobt.RowStatus,
		  root_hobt.Name
  FROM
          SCore.Markets AS root_hobt
  OUTER APPLY	SCore.ObjectSecurityForUser (	root_hobt.Guid,
													@UserId
												) AS os
 WHERE (root_hobt.RowStatus NOT IN (0,254))
 
          
GO