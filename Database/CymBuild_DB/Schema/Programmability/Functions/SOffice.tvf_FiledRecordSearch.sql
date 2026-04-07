SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO


CREATE FUNCTION [SOffice].[tvf_FiledRecordSearch]
	(
		@MessageID NVARCHAR(250)
	)
RETURNS TABLE
AS
RETURN
	 (
		 SELECT
			sms.ID,
			sms.Guid,
			et.Name AS EntityTypeName,
			CASE 
				WHEN FiledStatusMatch.FilingLocationUrl = '' THEN sms.Name
				ELSE '<a href="' + FiledStatusMatch.FilingLocationUrl + '">' + sms.Name + '</a>'
			END AS Name,
			FiledStatusMatch.IsFiled,
			FiledStatusMatch.FilingLocationUrl
		FROM
			SOffice.TargetObjects sms
		JOIN
			SOffice.EntityTypes et ON (et.ID = sms.EntityTypeId)
		OUTER APPLY
			(
				SELECT
					oe.Guid,
					oe.IsFiled,
					oe.FilingLocationUrl,
					oe.MessageID
				FROM
					SOffice.OutlookEmails AS oe
				JOIN
					SOffice.TargetObjects AS t ON (t.ID = oe.TargetObjectID)
				WHERE
					(et.ID = t.EntityTypeId)
					AND (sms.ID = oe.TargetObjectID)
					AND (oe.MessageID = @MessageID)
					AND (REPLACE(oe.Subject, N'RE: ', N'') = REPLACE(oe.Subject, N'RE: ', N''))
			) AS FiledStatusMatch
		WHERE
			FiledStatusMatch.MessageID = @MessageID
		GROUP BY
			FiledStatusMatch.IsFiled,
			sms.ID,
			sms.Guid,
			et.Name,
			sms.Name,
			FiledStatusMatch.FilingLocationUrl
					
	 );


GO