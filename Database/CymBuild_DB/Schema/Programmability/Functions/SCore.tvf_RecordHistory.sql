SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[tvf_RecordHistory] 
(
    @UserId INT,
    @ParentGuid UNIQUEIDENTIFIER
)
RETURNS TABLE
             --WITH SCHEMABINDING
AS
RETURN 
SELECT  rh.ID,
        rh.RowStatus, 
        rh.RowVersion,
        rh.Guid,
        rh.Datetime,
		i.FullName,
	 	lt.Label AS Property,
		rh.PreviousValue,
		rh.NewValue
FROM    SCore.RecordHistory rh
JOIN	SCore.EntityProperties ep ON (ep.ID = rh.EntityPropertyID)
JOIN	SCore.Identities i ON (i.ID = rh.UserID)
OUTER APPLY SCore.ObjectSecurityForUser(ep.Guid, @UserId) ep_os
OUTER APPLY SCore.ObjectSecurityForUser(rh.RowGuid, @UserId) os
OUTER APPLY	SCore.ObjectLabelForUser (	 ep.LanguageLabelID,
												 @UserId
											 ) AS lt
WHERE   (rh.RowStatus  NOT IN (0, 254))
    AND (rh.RowGuid = @ParentGuid)
    AND (os.CanRead = 1)
GO