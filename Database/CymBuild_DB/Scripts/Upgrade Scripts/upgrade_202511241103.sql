
DISABLE TRIGGER SCore.tg_WorkflowStatus_RecordHistory ON SCore.WorkflowStatus;


UPDATE SCore.WorkflowStatus
SET Name = N'N/A',
	Description = N'Used when importing legacy statuses',
	ShowInEnquiries = 1,
	ShowInQuotes = 1,
	ShowInJobs = 1,
	IsPredefined = 1,
	SortOrder = 1,
	Icon = N'fa-database',
	Colour = N'#B3E5FC',
	IsActiveStatus = 1
WHERE Guid = '00000000-0000-0000-0000-000000000000';



ENABLE TRIGGER SCore.tg_WorkflowStatus_RecordHistory ON SCore.WorkflowStatus;

