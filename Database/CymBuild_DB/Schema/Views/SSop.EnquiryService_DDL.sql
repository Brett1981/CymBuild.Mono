SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SSop].[EnquiryService_DDL]
	--WITH SCHEMABINDING
AS
SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.Guid,
		e.Number + N' - ' + jt.[Name]	AS [Name]	
FROM	SSop.EnquiryServices AS root_hobt
JOIN	SSop.Enquiries AS e ON (e.ID = root_hobt.EnquiryId)
JOIN	SJob.JobTypes AS jt ON (jt.ID = root_hobt.JobTypeId)
GO