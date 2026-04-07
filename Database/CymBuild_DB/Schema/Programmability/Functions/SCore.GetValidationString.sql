SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE FUNCTION [SCore].[GetValidationString]
(
	@ValidationResults SCore.ValidationResult READONLY
)
RETURNS NVARCHAR(MAX)
AS 
BEGIN 
	DECLARE	@ResultString NVARCHAR(MAX) = N''


	SELECT	@ResultString += STUFF (
										 (
											 SELECT N', ' + CHAR(10) + CHAR(9) + COALESCE(ep.NAME, eh.ObjectName, epg.NAME) + N' : ' + vr.Message
											 FROM		@ValidationResults AS vr
											 LEFT JOIN	SCore.EntityProperties ep ON (ep.Guid = vr.TargetGuid)
											 LEFT JOIN	SCore.EntityHobts eh ON (eh.Guid = vr.TargetGuid)
											 LEFT JOIN	SCore.EntityPropertyGroups epg ON (epg.Guid = vr.TargetGuid)
											 WHERE		(vr.IsInvalid = 1)
											 FOR XML PATH ('')
										 ),
										 1,
										 1,
										 ''
										   );

	RETURN @ResultString
END
GO