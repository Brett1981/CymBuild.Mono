SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO





CREATE VIEW [SSop].[ScheduleOfClientInfo_MergeInfo]
AS
SELECT		soci.ID,
			soci.RowStatus,
			soci.RowVersion,
			soci.Guid,
			soci.Item,
			e.Guid AS ParentGuid
FROM		SSop.ScheduleOfClientInformation AS soci
JOIN		SSop.Enquiries AS e ON (e.ID = soci.EnquiryId)


GO