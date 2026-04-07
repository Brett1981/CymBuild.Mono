SET QUOTED_IDENTIFIER, ANSI_NULLS ON
GO
CREATE VIEW	[SSop].[Quote_ExtendedInfo]
    --WITH SCHEMABINDING
AS
SELECT	q.Id,
		q.RowStatus,
		q.RowVersion,
		q.Guid,
		e.ID EnquiryID, 
		e.QuotingDeadlineDate,
		e.ClientAccountID,
		CASE WHEN q.ClientAddressId = -1 THEN e.ClientAddressId ELSE q.ClientAddressId END AS ClientAddressId,
		e.ClientAccountContactId,
		e.AgentAccountID,
		CASE WHEN q.AgentAddressId = -1 THEN e.AgentAddressId ELSE q.AgentAddressId END AS AgentAddressId,
		--ACForAgent.Guid AS AgentAccountContactId,
		CASE WHEN e.IsClientFinanceAccount = 1 THEN e.ClientAccountId ELSE e.FinanceAccountId END AS FinanceAccountId,
		CASE WHEN e.IsClientFinanceAccount = 1 THEN e.FinanceAddressId ELSE e.FinanceAddressId END AS FinanceAddressId,
		CASE WHEN e.IsClientFinanceAccount = 1 THEN e.FinanceContactId ELSE e.FinanceContactId END AS FinanceContactId,
		e.PropertyId,
		CASE WHEN q.DescriptionOfWorks = '' THEN e.DescriptionOfWorks ELSE q.DescriptionOfWorks END AS DescriptionOfWorks, --[CBLD-588]
		jt.Name AS JobType,
		jt.Guid AS JobTypeGuid,
		AC.Guid AS ClientContactId,
		e.AgentAccountContactId
FROM	SSop.Quotes q 
LEFT JOIN	SSop.EnquiryServices es ON (es.ID = q.EnquiryServiceID)
LEFT JOIN	SSop.Enquiries e ON (e.ID = es.EnquiryId)
LEFT JOIN	SJob.JobTypes AS jt ON (jt.ID = es.JobTypeId)
JOIN SCrm.AccountContacts AS AC ON (e.ClientAccountContactId = AC.ID)
JOIN SCrm.AccountContacts AS ACForAgent ON (e.AgentAccountContactId = ACForAgent.ID)
GO