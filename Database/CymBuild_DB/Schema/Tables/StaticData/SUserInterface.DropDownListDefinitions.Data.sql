SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions ON
GO
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (-1, 1, '00000000-0000-0000-0000-000000000000', N'', N'', N'', N'', N'', N'', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (1, 1, '95dfe2aa-5274-4ca0-85c0-5a28f9f07504', N'EntityDataTypes', N'Name', N'Guid', N'SELECT Guid, Name FROM SCore.EntityDataTypes root_hobt', N'Name', N'0', N'', 0, 40, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (2, 1, '85b52083-b518-4585-92be-63cc85a6ba02', N'LanguageLabels', N'Name', N'Guid', N'SELECT Name, Guid FROM SCore.LanguageLabels root_hobt', N'Name', N'0', N'LanguageLabelDetail', 1, 2, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (3, 1, '2f119bd0-cb01-49e0-99f7-dc436cf018c4', N'PropertyGroups', N'Name', N'Guid', N'SELECT  root_hobt.Name, root_hobt.Guid 
FROM    Score.EntityPropertyGroups root_hobt 
WHERE   ((EXISTS
            (
                SELECT  1
                FROM    SCore.EntityProperties ep 
                JOIN    SCore.EntityHoBTs h on (ep.EntityHoBTID = h.ID)
                WHERE   (ep.Guid = ''[[RecordGuid]]'')
                    AND (h.EntityTypeID = root_hobt.EntityTypeID)
            )
        ) OR (ID = -1))', N'Name', N'0', N'', 0, 14, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (4, 1, 'dac62177-a9f1-4f07-b988-da089dcf911a', N'DropDownLists', N'Code', N'Guid', N'SELECT Guid, Code FROM SUserInterface.DropDownListDefinitions root_hobt', N'Code', N'0', N'DynamicEdit', 1, 10, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (5, 1, '762e0924-1e10-474a-a519-abc2e8c0c833', N'EntityHoBTs', N'Name', N'Guid', N'SELECT SchemaName + N''.'' + ObjectName as Name, root_hobt.Guid, root_hobt.ObjectName FROM SCore.EntityHoBTs root_hobt JOIN SCore.EntityTypes et on (et.ID = root_hobt.EntityTypeID) WHERE (et.Guid = ''[[ParentGuid]]'')', N'ObjectName', N'0', N'', 0, 5, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (6, 1, '9ab60b95-b492-4469-8147-caecc47b6a20', N'EntityTypes', N'Name', N'Guid', N'SELECT Guid, Name FROM SCore.EntityTypes root_hobt', N'Name', N'0', N'', 0, 4, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (7, 1, '6f399d03-cc70-4442-b7ab-d9a1951009b7', N'EntityHobts_NoFilter', N'Name', N'Guid', N'SELECT SchemaName + N''.'' + ObjectName as Name, root_hobt.Guid, root_hobt.ObjectName FROM SCore.EntityHoBTs root_hobt', N'ObjectName', N'0', N'', 0, 5, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (8, 1, '4746ef94-0489-499d-b2c6-a069ab705cba', N'EntityQueries', N'Name', N'Guid', N'SELECT Guid, Name FROM SCore.EntityQueries root_hobt', N'Name', N'0', N'', 0, 7, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (9, 1, '3f897dcf-0999-46bb-88ff-41c428162595', N'EntityProperties', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		N''['' + h.SchemaName + ''].['' + h.ObjectName + ''].['' + root_hobt.Name + '']'' AS Name
FROM	SCore.EntityProperties AS root_hobt
JOIN	SCore.EntityHobts h ON (h.ID = root_hobt.EntityHoBTID)
WHERE	(root_hobt.Id = root_hobt.ID)
	OR	(root_hobt.Guid = ''[[CurrentSelectedValueGuid]]'')', N'Name', N'0', N'', 0, 6, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (10, 1, '7a18b223-1408-4691-8e84-5a3ba2cce266', N'MappedEntityProp', N'Name', N'Guid', N'SELECT
        root_hobt.Guid,
        root_hobt.Name
FROM
        SCore.EntityProperties root_hobt
    JOIN
        SCore.EntityHoBTs      h
            ON (root_hobt.EntityHoBTID = h.ID)
    JOIN
        SCore.EntityQueries    eq
            ON (h.EntityTypeID = eq.EntityTypeID)
WHERE
        (
            (eq.Guid = ''[[ParentGuid]]'')
            AND (''[[ParentGuid]]'' != ''00000000-0000-0000-0000-000000000000'')
        )
        OR
            (
                (''[[ParentGuid]]'' = ''00000000-0000-0000-0000-000000000000'')
                AND ((EXISTS
    (
        SELECT
            1
        FROM
            SCore.EntityQueryParameters eqp
        WHERE
            (eqp.Guid = ''[[RecordGuid]]'')
            AND (eq.ID = eqp.EntityQueryID)
    )
                     )
                    )
            )', N'root_hobt.Name', N'0', N'', 0, 6, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (11, 1, '016fa122-ccc2-436a-accc-9514af0eb85b', N'Grids', N'Code', N'Guid', N'SELECT root_hobt.Code, root_hobt.Guid
FROM SUserInterface.GridDefinitions root_hobt', N'Code', N'0', N'', 0, 11, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (12, 1, '57380065-bd86-4d03-aa70-c63312abbe1e', N'MetricTypes', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid
FROM SUserInterface.MetricTypes root_hobt', N'Name', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (13, 1, '5235f41a-8c2f-46f5-a579-f3b097ae7201', N'GridViews', N'Name', N'Guid', N'SELECT  olfu.Label AS [Name],
        root_hobt.Guid
FROM    SUserInterface.GridViewDefinitions root_hobt
OUTER APPLY	SCore.ObjectLabelForUser(root_hobt.LanguageLabelId,[[UserId]]) olfu', N'Name', N'0', N'', 0, 12, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (14, 1, '5cb19e71-6160-4359-982e-306408eceb1f', N'Identities', N'FullName', N'Guid', N'SELECT root_hobt.Guid,
       root_hobt.FullName
FROM SCore.Identities root_hobt
WHERE	(root_hobt.IsActive = 1)
	OR	(root_hobt.Guid = ''[[CurrentSelectedValueGuid]]'')', N'FullName', N'0', N'', 0, 42, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (15, 1, 'abcd7feb-85af-4354-8750-fb5f2375c97b', N'JobTypes', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid
FROM SJob.JobTypes root_hobt', N'Name', N'0', N'', 0, 41, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (16, 1, '2d399d23-bb47-46a6-9007-d1fb584985c9', N'OrganisationalUnits', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name  FROM SCore.OrganisationalUnits root_hobt', N'Name', N'0', N'', 0, 67, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (17, 1, 'bde30f92-4cb9-4c53-a314-cb94747f0004', N'CrmAccounts', N'Name', N'Guid', N'SELECT  TOP(10) root_hobt.Guid, root_hobt.Name
FROM    SCrm.Accounts root_hobt
WHERE	(root_hobt.Id = root_hobt.ID)', N'Name', N'0', N'AccountDetail', 1, 15, N'DynamicEdit', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (18, 1, '6bd79378-bf46-4f28-87c6-a15b71afc81f', N'CRMContact', N'DisplayName', N'Guid', N'SELECT TOP(10) root_hobt.Guid, root_hobt.DisplayName
FROM SCrm.Contacts root_hobt 
WHERE	(root_hobt.Id = root_hobt.ID)', N'DisplayName', N'0', N'ContactDetail', 1, 25, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (19, 1, '8f14dd94-0c36-4bd8-b98f-bc22c340cbe5', N'ActivityStatus', N'Name', N'Guid', N'SELECT  root_hobt.Guid, root_hobt.Name, root_hobt.SortOrder
FROM    SJob.ActivityStatus root_hobt', N'SortOrder', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (20, 1, '4dbf941e-59a0-4f99-94b7-15e944501502', N'ActivityType', N'Name', N'Guid', N'SELECT  root_hobt.Guid, root_hobt.Name
FROM    SJob.ActivityTypes root_hobt
', N'Name', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (21, 1, 'cb347601-929d-428a-8884-0416b1ac9702', N'Jobs', N'Number', N'Guid', N'SELECT TOP(10) root_hobt.Number, root_hobt.Guid
FROM Sjob.Jobs root_hobt', N'Number', N'0', N'JobDetail', 0, 9, N'DynamicEdit', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (22, 1, 'a8db217c-21e4-49c5-8eb9-fa7d8a784fe4', N'ASSETS', N'ListLabel', N'Guid', N'SELECT TOP(10) root_hobt.Guid, root_hobt.ListLabel, root_hobt.AssetNumber
FROM SJob.Assets root_hobt   ', N'AssetNumber', N'0', N'StructureDetail', 1, 27, N'DynamicEdit', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (23, 1, 'a1ad71a1-8f9e-4848-a8b9-4679780269c2', N'AccountStatus', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name 
from SCrm.AccountStatus root_hobt', N'Name', N'0', N'', 0, 39, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (24, 1, 'f7be6287-3578-4c14-bbf7-40021e494fc0', N'LANGUAGES', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name FROM SCore.Languages root_hobt', N'Name', N'0', N'', 0, 1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (25, 1, 'dc4c03dd-39b0-4910-b494-5af7e1d71f56', N'MILESTONETYPES', N'Name', N'Guid', N'SELECT	root_hobt.Guid, root_hobt.Name
FROM	SJob.MilestoneTypes root_hobt', N'Name', N'0', N'DynamicEdit', 1, 48, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (26, 1, '2c765fe8-9a51-4957-9a78-ff337456aac9', N'VALUESOFWORK', N'Name', N'Guid', N'SELECT	root_hobt.Name,
		root_hobt.Guid,
		root_hobt.SortOrder
FROM	SJob.ValuesOfWork AS root_hobt', N'SortOrder', N'0', N'', 0, 49, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (27, 1, '7659d894-7a94-4ca7-a028-d30c178303d6', N'JOBMILESTONES', N'Description', N'Guid', N'SELECT	CASE WHEN root_hobt.Description = N'''' THEN mt.Name ELSE root_hobt.Description END as Description,
		root_hobt.Guid
FROM	SJob.Milestones AS root_hobt
JOIN	SJob.MilestoneTypes mt ON (mt.ID = root_hobt.MilestoneTypeID)
JOIN	SJob.Jobs j ON (j.ID = root_hobt.JobID)
WHERE	(j.Guid = ''[[ParentGuid]]'')
	AND	(root_hobt.RowStatus NOT IN (0, 254))', N'Description', N'0', N'MilestoneDetail', 1, 33, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (28, 1, 'a259db92-7bcf-46c2-8a6b-7d208416b2d9', N'JOBACTIONS', N'Notes', N'Guid', N'SELECT	root_hobt.Notes,
		root_hobt.Guid
FROM	SJob.Actions AS root_hobt
WHERE	(EXISTS
			(
				SELECT	1
				FROM	SJob.Actions a
				WHERE	(a.Guid = ''[[ParentGuid]]'')
					AND	(a.JobID = root_hobt.JobID)
			)
		)', N'ID', N'0', N'DynamicEdit', 1, 43, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (29, 1, 'fce76f9e-f7bf-433a-a20b-16b1d218486f', N'PROJECTDIRECTORYROLE', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SJob.ProjectDirectoryRoles AS root_hobt
WHERE	(root_hobt.RowStatus NOT IN (0, 254))', N'Name', N'0', N'', 1, 36, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (30, 1, 'e576096d-1254-4bdf-8a3d-888da2cb1217', N'CONTRACTS', N'Name', N'Guid', N'SELECT	TOP(10) root_hobt.Guid,
		root_hobt.Name
FROM	SSop.Contracts_DDL root_hobt
WHERE	(root_hobt.AccountGuid = ''[[ParentGuid]]'')', N'Name', N'0', N'DynamicEdit', 1, 50, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (31, 1, 'd1af6ef8-65f6-463a-86eb-ef354a5316be', N'JOBACTIONACTIVITIES', N'Title', N'Guid', N'SELECT	root_hobt.Title,
		root_hobt.Guid
FROM	SJob.Activities AS root_hobt
JOIN	SJob.Jobs j ON (j.ID = root_hobt.JobID)
WHERE	(j.Guid = ''[[ParentGuid]]'')', N'Title', N'0', N'ActivityDetail', 1, 30, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (32, 1, 'ee2ca583-f3b6-4af1-81db-d82be95af299', N'ADDRESSES', N'Name', N'Guid', N'SELECT	TOP(10) root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.AddressesDropDown root_hobt', N'Name', N'0', N'AddressDetail', 1, 18, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (33, 1, 'c056ac1d-2a30-474f-b37f-7385d8ef3b89', N'AccountContact_Accou', N'Name', N'Guid', N'SELECT root_hobt.Id, root_hobt.Guid, CONVERT(nvarchar(100), a.Number) + N'' - '' + a.FormattedAddressComma as Name
FROM SCrm.AccountAddresses  root_hobt
JOIN	SCrm.Addresses a ON (a.ID = root_hobt.AddressID)
JOIN	SCrm.Accounts acc ON (acc.ID = root_hobt.AccountID)
WHERE (root_hobt.RowStatus NOT IN (0, 254))
	AND	(acc.Guid = ''[[ParentGuid]]'')', N'Name', N'0', N'', 1, 16, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (34, 1, '1fc84b64-8211-4c62-94e3-791d8ddfced3', N'CONTACTTITLES', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name FROM SCrm.tvf_ContactTitles([[UserId]]) root_hobt', N'Name', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (35, 1, '61f1ed47-b1ce-4505-85fe-6ea242122bc5', N'CONTACTPOSITIONS', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name from SCrm.tvf_ContactPositions([[UserId]]) root_hobt', N'Name', N'0', N'DynamicEdit', 1, 24, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (36, 1, '4a5b124f-6b5c-4d65-8fc5-27220e819423', N'QUOTES', N'Number', N'Guid', N'SELECT	TOP(10) root_hobt.Number, root_hobt.Guid
FROM	SSop.tvf_Quotes([[UserId]]) root_hobt
WHERE	(root_hobt.Id = root_hobt.ID)', N'Number', N'0', N'QuoteDetail', 0, 55, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (37, 1, '290fd51f-5405-4bfb-87e5-1a2343521a9d', N'PRODUCTS', N'ListName', N'Guid', N'SELECT	root_hobt.ListName, root_hobt.Guid
FROM	SProd.tvf_Products([[UserId]]) root_hobt', N'ListName', N'0', N'', 0, 51, N'ProductDetail', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (38, 1, 'abb4124a-255d-4766-8d72-77257023144e', N'QUOTESECTIONS', N'Name', N'Guid', N'SELECT	root_hobt.Name, root_hobt.Guid
FROM	SSop.QuoteSections root_hobt', N'Name', N'0', N'', 0, 56, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (39, 1, '2556eed1-f9a6-4f50-a44b-1806ecd2e23a', N'QUOTESOURCES', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SSop.QuoteSources root_hobt', N'Name', N'0', N'', 0, 62, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (40, 1, '24255795-d44b-48f4-a0de-25c650444472', N'TRANSACTIONTYPES', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SFin.TransactionTypes root_hobt ', N'Name', N'0', N'', 0, 63, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (41, 1, '70ea5172-3dcf-4a69-8db7-e81378b5c04d', N'propertygrouplayouts', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid 
FROM	SUserInterface.PropertyGroupLayouts root_hobt', N'', N'0', N'', 0, 66, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (42, 1, 'b942c21c-a0ef-4179-b75b-aef0c0fcc835', N'ACCONTADDRESS', N'Name', N'Guid', N'SELECT	TOP(10) root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.AccountAddressesDropDown root_hobt
WHERE	(root_hobt.AccountGuid = ''[[ParentGuid]]'')', N'Name', N'0', N'DynamicEdit', 1, 16, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (43, 1, '5a095709-9f6a-4e0f-95aa-ed7132d8a770', N'ACCOUNTCONTACT', N'DisplayName', N'Guid', N'SELECT	TOP(10) root_hobt.Guid,
		root_hobt.DisplayName
FROM	SCrm.AccountContactsDropDown AS root_hobt
WHERE	(root_hobt.AccountGuid = ''[[ParentGuid]]'')', N'DisplayName', N'0', N'DynamicEdit', 1, 17, N'AccountContactDetail', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (44, 1, '548c9f8c-9cd8-4a3d-a76e-a5ab2981abd6', N'ACTIVITIES', N'Title', N'Guid', N'SELECT	root_hobt.Guid, root_hobt.Title, j.Number
FROM	SJob.Activities root_hobt
JOIN	SJob.Jobs j ON (j.ID = root_hobt.JobID)
', N'Title', N'0', N'', 0, 30, N'', N'Number', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (45, 1, 'fd88d093-ce2d-4c35-b604-d1114ca4b673', N'RIBASTAGES', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid, root_hobt.Number
FROM SJob.RibaStageList root_hobt', N'Number', N'0', N'', 0, 70, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (46, 1, '37859e4e-d708-4c6a-9a53-4e3ea6c4881e', N'TRANSACTIONS', N'Name', N'Guid', N'SELECT	TOP(10) root_hobt.Guid,
		root_hobt.Name
FROM	SFin.AllTransactions root_hobt
WHERE	(root_hobt.ID > 0)', N'', N'0', N'TransactionDetail', 1, 37, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (47, 1, '5517a824-5ab6-4161-a225-5ae3eb38ca76', N'PRICELISTS', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name
FROM SSop.PriceLists root_hobt', N'Name', N'0', N'PriceListDetail', 0, 52, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (48, 1, 'cde841b0-8b25-4d3f-8f4f-6bf79741737f', N'JOBACTIVITYTYPES', N'Name', N'Guid', N'SELECT  root_hobt.Guid, 
		root_hobt.Name
FROM    SJob.ActivityTypes root_hobt
WHERE	(EXISTS 
			(
				SELECT	1
				FROM	SJob.Jobs j 
				JOIN	SJob.JobTypeActivityTypes jtat ON (jtat.JobTypeID = j.JobTypeID)
				WHERE	(j.Guid = ''[[ParentGuid]]'')
					AND	(jtat.ActivityTypeID = root_hobt.ID)
					AND	(jtat.RowStatus NOT IN (0, 254))
			)
		)', N'Name', N'0', N'', 0, 28, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (49, 1, '49255823-3c63-49a3-85b9-9dc8bc6e2fdc', N'COUNTRIES', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.Countries root_hobt
WHERE	(root_hobt.id > 0)
	AND	(root_hobt.RowStatus NOT IN (0, 254))', N'Name', N'0', N'', 1, 69, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (50, 1, 'f8b699d2-f678-47c2-b185-060a7d609fa8', N'COUNTIES', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.Counties root_hobt
WHERE	(root_hobt.id > 0)
	AND	(root_hobt.RowStatus NOT IN (0, 254))', N'Name', N'0', N'', 1, 68, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (51, 1, '58f65edc-90e0-483e-b74e-11601174b550', N'CONTACTDETAILTYPES', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.ContactDetailTypes root_hobt', N'Name', N'0', N'', 1, 23, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (52, 1, '9cf1f5d0-7406-434d-aa46-33b453bbde51', N'QUOTE_QUOTESECTIONS', N'Name', N'Guid', N'SELECT	root_hobt.Name, 
		root_hobt.Guid
FROM	SSop.QuoteSections root_hobt
JOIN	SSop.Quotes q ON (q.ID = root_hobt.QuoteId)
WHERE	(q.Guid = ''[[ParentGuid]]'')
	AND	(root_hobt.Guid <> ''[[RecordGuid]]'')', N'Name', N'0', N'', 0, 56, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (53, 1, 'bc6a3743-3b36-44da-9449-b9dd4d2a7ae6', N'SHAREPOINTSITES', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SCore.SharepointSites root_hobt', N'Name', N'0', N'', 1, 160, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (54, 1, '32302e27-b4e1-4b07-be27-2d186295364f', N'ENQUIRIES', N'Number', N'Guid', N'SELECT	CONVERT(NVARCHAR(50), root_hobt.Number) Number,
		root_hobt.Guid
FROM	SSop.Enquiries root_hobt
WHERE	(root_hobt.Id = root_hobt.ID)
	OR	(root_hobt.Guid = ''[[CurrentSelectedValueGuid]]'')', N'Number', N'0', N'EnquiryDetail', 0, 83, N'DynamicEdit', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (55, 1, 'f4093f5f-5e67-4311-8e77-1aa3fd7ed466', N'GROUP', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SCore.Groups root_hobt', N'Name', N'0', N'', 1, 87, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (56, 1, '402c65cb-bae8-4bcd-8264-c21e836f020c', N'PURPOSEGROUPS', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SJob.PurposeGroups root_hobt', N'Name', N'0', N'', 1, 45, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (57, 1, '9dda4488-f469-4d46-85c0-5d4e2283da7a', N'MILESTONES', N'Description', N'Guid', N'SELECT	CASE WHEN root_hobt.Description = N'''' THEN mt.Name ELSE root_hobt.Description END as Description,
		root_hobt.Guid
FROM	SJob.Milestones AS root_hobt
JOIN	SJob.MilestoneTypes mt ON (mt.ID = root_hobt.MilestoneTypeID)
WHERE	(root_hobt.RowStatus NOT IN (0, 254))', N'Description', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (58, 1, '8cd65ffa-60ad-449a-af5f-1c0d95a941fe', N'WATERAUTHORITIES', N'Name', N'Guid', N'SELECT  TOP(10) root_hobt.Guid, root_hobt.Name
FROM    SCrm.Accounts root_hobt
WHERE	(root_hobt.IsWaterAuthority = 1)', N'Name', N'0', N'', 0, 15, N'', N'', N'#000000', N'https://www.water.org.uk/customers/find-your-supplier');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (59, 1, '6857473c-e2b1-4bc2-9d5a-709d8f3d880a', N'FIREAUTHORITIES', N'Name', N'Guid', N'SELECT  TOP(10) root_hobt.Guid, root_hobt.Name
FROM    SCrm.Accounts root_hobt
WHERE	(root_hobt.IsFireAuthority = 1)', N'Name', N'0', N'', 0, 15, N'', N'', N'#000000', N'https://fireengland.uk/your-fire-and-rescue-service/find-your-service');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (60, 1, '7731eaf0-280c-492f-bc5e-eb9713d7aa6e', N'LOCALAUTHORITIES', N'Name', N'Guid', N'SELECT  TOP(10) root_hobt.Guid, root_hobt.Name
FROM    SCrm.Accounts root_hobt
WHERE	(root_hobt.IsLocalAuthority = 1)', N'Name', N'0', N'', 0, 15, N'', N'', N'#000000', N'https://www.gov.uk/find-local-council');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (61, 1, '0ce25644-83dc-4638-98f2-7fd63d181b88', N'INVOICECONTACT', N'DisplayName', N'Guid', N'SELECT root_hobt.Guid, root_hobt.DisplayName
FROM SCrm.Contacts root_hobt
WHERE	(EXISTS
			(
				SELECT	1
				FROM	SCrm.AccountContacts ac
				WHERE	(root_hobt.ID = ac.ContactID)
					AND	(ac.RowStatus NOT IN (0, 254))
					AND	(EXISTS
							(
								SELECT	1
								FROM	SJob.Jobs j 
								WHERE	(j.Guid = ''[[RecordGuid]]'')
									AND	(j.RowStatus NOT IN (0, 254))
									AND	(
											(j.ClientAccountID = ac.AccountID)
										OR	(j.AgentAccountID = ac.AccountID)
										)
							)
						)										
			)
		)', N'DisplayName', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (62, 1, '057273bc-3784-4f65-b0bd-d860d27d0667', N'LIVE_CRMACCOUNTS', N'Name', N'Guid', N'SELECT TOP(10)	root_hobt.Guid,
				root_hobt.Name
FROM	 SCrm.LiveAccounts root_hobt', N'Name', N'0', N'AccountDetail', 1, 15, N'DynamicEdit', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (63, 1, 'd21d5a03-85d0-4316-936f-0431f3d116c7', N'TRANSACTIONJOBMILEST', N'Label', N'Guid', N'SELECT	CASE
			WHEN root_hobt.Description = N'''' THEN mt.Name
			ELSE root_hobt.Description
		END AS Label,
		root_hobt.Description,
		root_hobt.Guid
FROM	SJob.Milestones		AS root_hobt
JOIN	SJob.MilestoneTypes AS mt ON (mt.ID = root_hobt.MilestoneTypeID)
JOIN	SJob.Jobs			AS j ON (j.ID	= root_hobt.JobID)
JOIN	SFin.Transactions	AS t ON (t.JobID = j.ID)
WHERE	(t.Guid = ''[[ParentGuid]]'')
	AND (root_hobt.RowStatus NOT IN (0, 254))', N'Description', N'0', N'', 0, 33, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (64, 1, 'b90b3c03-98f3-4dba-ae87-2f9e1d15407e', N'TRANSACTIONJOBACTIVI', N'Title', N'Guid', N'SELECT	root_hobt.Title,
		root_hobt.Guid
FROM	SJob.Activities		AS root_hobt
JOIN	SJob.Jobs			AS j ON (j.ID	= root_hobt.JobID)
JOIN	SFin.Transactions	AS t ON (t.JobID = j.ID)
WHERE	(t.Guid = ''[[ParentGuid]]'')
	AND (root_hobt.RowStatus NOT IN (0, 254))', N'', N'0', N'', 0, 30, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (65, 1, '818ef409-29b8-4293-8d8d-9ebc3f20ee3d', N'ORGUNIT_DEPARTMENTS', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name  FROM SCore.OrganisationalUnits root_hobt WHERE (root_hobt.IsDepartment = 1)', N'Name', N'0', N'', 0, 67, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (66, 1, '0742ca2c-54ff-4618-ae34-fb74710d5bd2', N'ORGUNIT_IDENTITIES', N'FullName', N'Guid', N'SELECT root_hobt.Guid,
       root_hobt.FullName
FROM	SCore.Identities root_hobt
JOIN	SCore.OrganisationalUnits ou ON (ou.ID = root_hobt.OriganisationalUnitId)
WHERE	((
			(root_hobt.IsActive = 1)
		AND	(EXISTS
				(
					SELECT	1
					FROM	SCore.OrganisationalUnits pou
					WHERE	(pou.Guid = ''[[ParentGuid]]'')
						AND	(ou.OrgNode.IsDescendantOf(pou.OrgNode) = 1)
				)
			)
		))', N'FullName', N'0', N'', 0, 42, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (67, 1, '71ca304a-8a80-403c-a725-38eae0e02aaf', N'ACCOUNT_ACCOUNTADDRE', N'Name', N'Guid', N'SELECT	TOP(10) root_hobt.Guid,
		root_hobt.Name
FROM	SCrm.AccountAddressesDropDown root_hobt
WHERE	(root_hobt.AccountGuid = ''[[RecordGuid]]'')', N'Name', N'0', N'', 0, 16, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (68, 1, 'd1a450ff-e8fb-4492-a73b-c221a54a3133', N'ACCOUNT_ACCOUNTCONTA', N'DisplayName', N'Guid', N'SELECT	TOP(10) root_hobt.Guid,
		root_hobt.DisplayName
FROM	SCrm.AccountContactsDropDown AS root_hobt
WHERE	(root_hobt.AccountGuid = ''[[RecordGuid]]'')', N'DisplayName', N'0', N'', 0, 17, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (69, 1, 'ba0f648d-3bb6-4ea4-a08e-cdbfe7690a26', N'CREDITTERMS', N'Name', N'Guid', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM	SFin.CreditTerms root_hobt', N'Name', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (70, 1, '8c85950e-63c0-4abe-83dc-91add9737744', N'PROJECTS', N'ListLabel', N'Guid', N'SELECT	TOP (10) root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.Guid,
		root_hobt.ListLabel
FROM	SSop.ProjectsList root_hobt', N'ListLabel', N'0', N'ProjectDetail', 1, 94, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (71, 1, '733c670f-c595-4621-932f-5762c2d64c22', N'ICONS', N'Name', N'Guid', N'SELECT
        root_hobt.ID,
        root_hobt.Guid,
        root_hobt.Name
FROM
        SUserInterface.Icons root_hobt
WHERE
        (root_hobt.RowStatus NOT IN (0, 254))', N'Name', N'0', N'DynamicEdit', 1, 105, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (72, 1, '0f212193-3ade-48cc-8d08-7566ab93e39c', N'ACTIONPRIORITIES', N'Name', N'Guid', N'SELECT  root_hobt.ID,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name	
FROM	SJob.ActionPriorities root_hobt', N'Name', N'0', N'DynamicEdit', 1, 113, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (73, 1, '10471b73-9363-4e99-8540-95c023572ccd', N'ACTIONTYPES', N'Name', N'Guid', N'SELECT  root_hobt.ID,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name	
FROM	SJob.ActionTypes root_hobt', N'Name', N'0', N'DynamicEdit', 1, 112, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (74, 1, 'e1c2f3aa-03b2-4349-ba7f-d720e468e423', N'ACTIONSTATUS', N'Name', N'Guid', N'SELECT  root_hobt.ID,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name	
FROM	SJob.ActionStatus root_hobt', N'Name', N'0', N'DynamicEdit', 1, 114, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (75, 1, '941defe9-5684-427c-a212-2020fb162538', N'MERGEDOCUMENTS', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SCore.MergeDocuments root_hobt', N'', N'0', N'', 0, 60, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (76, 1, '903e696f-655c-45a5-b647-cbbe076bd7f9', N'JOBPAYMENTSTAGES', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SJob.JobPaymentStages_List root_hobt', N'Name', N'0', N'', 0, 119, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (77, 1, '5a45b0fe-47ef-4989-ad53-c40aca433ebf', N'PAYMENTFREQUENCYTYPE', N'Name', N'Guid', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name 
FROM	SFin.PaymentFrequencyTypes root_hobt', N'Name', N'0', N'', 0, 118, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (78, 1, '8999981c-e9c6-4490-8e19-f7af3e19264f', N'GRIDVIEWTYPES', N'Name', N'Guid', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		root_hobt.Name
FROM	SUserInterface.GridViewTypes root_hobt
WHERE	(root_hobt.RowStatus NOT IN (0, 254))', N'Name', N'0', N'', 1, 121, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (79, 1, 'f030b382-a3e2-47e4-a788-55692bbfc9f5', N'ORGUNITS_BUSINESSUNI', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name  FROM SCore.OrganisationalUnits root_hobt WHERE (root_hobt.IsBusinessUnit = 1)', N'Name', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (80, 1, '47ef54c5-c64b-47c2-9eb8-c17e3606c552', N'JOBTYPEACTIVITYYPES', N'Name', N'Guid', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		atype.Name
FROM	SJob.JobTypeActivityTypes AS root_hobt
JOIN	SJob.ActivityTypes AS atype ON (atype.ID = root_hobt.ActivityTypeID)
WHERE	(EXISTS
			(
				SELECT	1
				FROM	SProd.Products AS p 
				WHERE	(p.Guid = ''[[ParentGuid]]'')
					AND	(p.CreatedJobType = root_hobt.JobTypeID)
			)
		)
	AND	(root_hobt.RowStatus NOT IN (0, 254))', N'Name', N'0', N'', 0, 28, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (81, 1, '09674ab4-887a-43fd-8342-f18dc4896344', N'JOBTYPEMILESTONETEMP', N'Name', N'Guid', N'SELECT	root_hobt.ID,
		root_hobt.RowStatus,
		root_hobt.RowVersion,
		root_hobt.Guid,
		mt.Name
FROM	SJob.JobTypeMilestoneTemplates AS root_hobt
JOIN	SJob.MilestoneTypes AS mt ON (mt.ID = root_hobt.MilestoneTypeID)
WHERE	(EXISTS
			(
				SELECT	1
				FROM	SProd.Products AS p 
				WHERE	(p.Guid = ''[[ParentGuid]]'')
					AND	(p.CreatedJobType = root_hobt.JobTypeID)
			)
		)
	AND	(root_hobt.RowStatus NOT IN (0, 254))', N'Name', N'0', N'', 0, 48, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (82, 1, '8f5bec50-81a3-4d38-8241-e98dad40e3b5', N'INVOICEREQUESTID', N'ID', N'Guid', N'SELECT  root_hobt.ID,  root_hobt.Guid
FROM SFin.InvoiceRequests root_hobt
WHERE (root_hobt.InvoiceRequestId = root_hobt.ID)', N'ID', N'0', N'', 0, 126, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (83, 1, 'ee6735a3-d009-465a-9b76-8088574c0869', N'MILESTONEID', N'Milestone ID', N'JobID', N'SELECT root_hobt.JobID
FROM SJob.tvf_JobMilestones([[UserId]], ''[[Guid]]'')
WHERE root_hobt.JobId = root_hobt.JobID', N'', N'0', N'', 0, 33, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (84, 1, 'f0c6e9e7-f25f-40f2-ba99-d80a075e76f5', N'INVOICEREQUEST_ACTIV', N'Title', N'Guid', N'SELECT  root_hobt.Guid, 
		(CASE WHEN root_hobt.Title = '''' THEN ''-'' ELSE CONCAT(root_hobt.Title, '' '', CASE WHEN Act.IsBillable = 1 THEN ''(Billable)'' ELSE ''(Non-Billable)'' END) END) AS Title,
                Act.IsBillable
FROM    SJob.Activities root_hobt
JOIN    SJob.ActivityTypes AS Act ON (root_hobt.ActivityTypeID = Act.ID)
JOIN    SJob.ActivityStatus AS ActStat ON (root_hobt.ActivityStatusID = ActStat.ID)
WHERE	(EXISTS 
			(
				SELECT	1
				FROM	SFin.InvoiceRequests AS ir
				WHERE	(ir.Guid = ''[[ParentGuid]]'')
					AND	(ir.JobId = root_hobt.JobID)
			)
		)  
		AND ActStat.Name = N''Complete''', N'IsBillable', N'0', N'', 0, 30, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (85, 1, '486c483b-470f-4f95-83fe-8f6b560de5bd', N'INVOICEREQUEST_MILES', N'Name', N'Guid', N'SELECT root_hobt.Guid,
             mt.Name
FROM  SJob.Milestones root_hobt INNER Join SJob.MilestoneTypes mt ON root_hobt.MilestoneTypeID = mt.ID
WHERE (EXISTS    (
                                SELECT 1
                                 FROM SFin.InvoiceRequests AS ir
                                 WHERE (ir.Guid = ''[[ParentGuid]]'')
                                 AND (ir.JobId = root_hobt.JobID)
                             )
               )', N'', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (86, 1, '3bbdeb2c-9810-48e7-a5be-152bf2594670', N'INVOICE_REQUESTS_FIN', N'Name', N'Guid', N'SELECT 
		ac.Name,
		ac.Guid
FROM 
		SJob.Jobs root_hobt
INNER JOIN SCrm.Accounts ac ON (ac.ID = root_hobt.FinanceAccountID)
WHERE (root_hobt.Guid =  ''[[ParentGuid]]'')', N'Name', N'0', N'', 1, 15, N'DynamicEdit', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (87, 1, '63352331-831d-4c9b-8b81-e966c8495be5', N'MERGEDOCUMENTITEMTYP', N'Name', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.Name
FROM	SCore.MergeDocumentItemTypes AS root_hobt', N'Name', N'0', N'DynamicEdit', 1, 154, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (88, 1, '7a089cd8-27e0-4979-92ba-fa18022b18ff', N'MERGEDOCUMENTITEMS', N'BookmarkName', N'Guid', N'SELECT	root_hobt.Guid,
		root_hobt.BookmarkName
FROM	SCore.MergeDocumentItems AS root_hobt', N'BookmarkName', N'0', N'', 0, 152, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (89, 1, '087eafbf-7447-48e8-a285-f3e9ab8ece0d', N'ENQUIRY_SERVICES', N'Name', N'Guid', N'SELECT	root_hobt.Guid, 
		root_hobt.Name
FROM	SSop.EnquiryService_DDL root_hobt', N'', N'0', N'', 0, 84, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (90, 1, 'f5dc3ad8-0030-4cee-bcd4-00132f195c16', N'QUOTEPRODUCTS', N'ListName', N'Guid', N'SELECT	TOP(10) root_hobt.ListName, 
		root_hobt.Guid
FROM	SProd.tvf_Products(1) root_hobt
WHERE	((root_hobt.CreatedJobType = -1)
	OR	(EXISTS
			(
				SELECT	1
				FROM	SSop.Quotes AS q
				JOIN	SSop.EnquiryServices es ON (es.ID = q.EnquiryServiceID)
				WHERE	(es.JobTypeId = root_hobt.CreatedJobType)
					AND	(q.Guid = ''[[ParentGuid]]'')
			)
		))', N'ListName', N'0', N'ProductDetail', 1, 51, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (91, 1, '34049715-9c1c-4083-9dbf-94a09b30abeb', N'CRMACCOUNTSMERGE', N'Name', N'Guid', N'SELECT TOP(10) root_hobt.Guid,
           CASE WHEN root_hobt.Code <> '''' THEN root_hobt.Name + '' - '' + root_hobt.Code
                ELSE root_hobt.Name
           END AS Name
    FROM SCrm.Accounts root_hobt', N'Name', N'0', N'AccountDetail', 1, 15, N'DynamicEdit', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (92, 1, '0031902a-b82c-4b50-9b3d-194a5d30b931', N'LIVE_CRMSAGECOLOURAC', N'ConcatenatedNameCode', N'Guid', N'SELECT TOP(10)
             root_hobt.ConcatenatedNameCode,
             root_hobt.Guid,
             root_hobt.ColourHex
FROM SCrm.LiveSageColourAccounts root_hobt', N'', N'0', N'AccountDetail', 1, 15, N'DynamicEdit', N'', N'#FFFFFF', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (93, 1, '7da1444e-4407-4c3b-8469-14851a5ed0fa', N'JOB TYPE - QUOTES', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid
FROM SJob.JobTypes root_hobt
', N'Name', N'0', N'', 0, 41, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (94, 1, '7c8670f3-4ec5-40d9-956d-f3d0804063f8', N'PROJECTDIRCONTACT', N'DisplayName', N'ContactGuid', N'SELECT	TOP(10)
		root_hobt .DisplayName,
		root_hobt .Guid AS ContactGuid
FROM	SCrm.Contacts root_hobt 
JOIN	SCrm.AccountContacts ac  ON (root_hobt .ID = ac.ContactID)
JOIN	SCrm.Accounts a ON (a.ID = ac.AccountID)
WHERE	(root_hobt.RowStatus NOT IN (0, 254))
	AND	(a.RowStatus NOT IN (0, 254))
	AND	(ac.RowStatus NOT IN (0, 254))
        AND         (a.Guid = ''[[ParentGuid]]'')', N'DisplayName', N'0', N'ContactDetail', 0, 25, N'', N'', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (95, 1, '27936593-6d42-4939-b7b8-28a2491aa335', N'NONACTIVITYTYPES', N'Name', N'Guid', N'SELECT  TOP(10)
	root_hobt.Name,
	root_hobt.Guid
FROM
	SCore.NonActivityTypes root_hobt', N'', N'0', N'', 0, -1, N'', N'', N'#000000', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (96, 1, '94ab4fa1-855d-4e23-bc40-427f89eae331', N'CONTRACTTYPES', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name
FROM SSop.ContractTypes root_hobt
WHERE 
	root_hobt.IsActive = 1  AND
	root_hobt.RowStatus NOT IN (0, 254)', N'Name', N'0', N'DynamicEdit', 1, 185, N'', N'', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (97, 1, 'e8913603-aecd-4759-8037-0944f7760356', N'ENTITYHOBT', N'Name', N'Guid', N'SELECT SchemaName AS Name, Guid  FROM SCore.EntityHoBTs ', N'', N'0', N'', 0, 5, N'', N'', N'#FFFFFF', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (98, 1, 'a20d3807-7b5d-4536-a6d6-2f2289783a11', N'WORKFLOWENTITY', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid 
FROM SCore.EntityTypes root_hobt
WHERE root_hobt.Name IN (N''Jobs'', N''Enquiries'', N''Quotes'')
', N'Name', N'0', N'', 0, 4, N'', N'', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (99, 1, '192f12f6-c7b0-4626-8e8d-8c5091456b93', N'WF_TRANSITION_STAGE', N'Name', N'Guid', N'SELECT  root_hobt.Guid, root_hobt.Name FROM [SCore].[WorkflowGetNextStatus](''[[ParentGuid]]'', ''[[RecordGuid]]'') root_hobt', N'Name', N'0', N'', 0, 190, N'', N'', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (100, 1, '7a0fb04a-e730-4af9-8f01-d5ff215eb5e2', N'WF_ORGUNITS', N'Name', N'Guid', N'SELECT 
	CASE WHEN root_hobt.Name = N'''' THEN N''All'' ELSE root_hobt.Name END AS Name,
	root_hobt.Guid 
FROM SCore.OrganisationalUnits AS root_hobt', N'Name', N'0', N'', 0, 67, N'', N'', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (101, 1, '784a20e2-1167-473d-9e0e-f71e144e8abf', N'WF_GET_STAGES', N'Name', N'Guid', N'SELECT 
             root_hobt.Name,
             root_hobt.Guid
FROM SCore.tvf_GetWorkflowStatuses (''[[ParentGuid]]'') root_hobt', N'Name', N'0', N'', 0, 187, N'', N'Name', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (102, 1, '807acb8c-82be-4f14-a93e-614f054a7b68', N'INVPAYSTATUS', N'Name', N'Guid', N'SELECT root_hobt.Guid, root_hobt.Name FROM [SFin].[InvoicePaymentStatus] AS root_hobt', N'', N'0', N'', 0, 196, N'', N'', N'', N'');

INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (103, 1, '170ab0fe-b239-43fb-85c5-c644cd867036', N'INVOICESCHEDULE', N'Name', N'Guid', N'SELECT 
	root_hobt.Name,
	root_hobt.Guid
FROM SFin.InvoiceScheduleTrigger AS root_hobt', N'', N'0', N'', 0, 198, N'', N'', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (104, 1, '4677922f-9013-403b-949a-29605fd72671', N'QUOTEITEMSINVOICINGS', N'Name', N'Guid', N'
SELECT root_hobt.Name, root_hobt.Guid
FROM SFin.InvoiceSchedules AS root_hobt
JOIN SSop.Quotes AS q ON (q.ID = root_hobt.QuoteId)
WHERE 
		(q.Guid = [[ParentGuid]])
	AND (root_hobt.RowStatus NOT IN (0,254))', N'Name', N'0', N'DynamicEdit', 0, 200, N'InvoicingScheduleDetail', N'', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (105, 1, 'f658d390-6de9-4373-8e58-f9212874adb4', N'GETMONTHS', N'Name', N'Guid', N'SELECT 
		root_hobt.MonthName AS Name,
		root_hobt.Guid
FROM SCore.Months  root_hobt', N'', N'0', N'', 0, -1, N'', N'', N'', N'');

GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions OFF
GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions ON
GO
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (106, 1, '56f212e4-5189-494a-ba7a-12e238d9bc79', N'SUBCONTRACTORACT', N'Name', N'Guid', N'SELECT 
	acttyp.Name, root_hobt.Guid 
FROM SJob.Activities AS root_hobt
JOIN SJob.Jobs AS j ON (j.ID =  root_hobt.JobID)
JOIN SJob.ActivityTypes as acttyp ON (root_hobt.ActivityTypeID = acttyp.ID)
WHERE (j.Guid = [[ParentGuid]])', N'', N'0', N'', 0, 30, N'', N'Name', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (107, 1, '7fdc41b9-2633-4746-8fe9-41fa0a8409d9', N'SUBCONTRACTORMIL', N'Name', N'Guid', N'



SELECT milt.Name, root_hobt.Guid
FROM SJob.Milestones as root_hobt
JOIN SJob.Jobs AS j ON (j.ID = root_hobt.JobID)
JOIN SJob.MilestoneTypes as milt ON (milt.ID = root_hobt.MilestoneTypeID)
WHERE (j.Guid = [[ParentGuid]])
', N'Name', N'0', N'', 0, 33, N'', N'', N'', N'');

GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions OFF
GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions ON
GO
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (108, 1, '96bce944-c23f-480e-b798-9c115d83814f', N'POACTIVITIES', N'Name', N'Guid', N'SELECT	root_hobt.Guid, root_hobt.Title, j.Number
FROM	SJob.Activities root_hobt
JOIN	SJob.Jobs j ON (j.Guid = [[ParentGuid]])
', N'', N'0', N'', 0, -1, N'', N'', N'', N'');

GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions OFF
GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions ON
GO
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (109, 1, '2a335d98-2c9e-45f9-b271-f51cf5aba728', N'WFSTATUSAUTH', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid 
FROM SCore.WorkflowTransition as wft
JOIN SCore.Workflow as wf ON (wf.ID = wft.WorkflowID)
JOIN SCore.WorkflowStatus AS root_hobt ON (root_hobt.ID = wft.ToStatusID)
WHERE wf.Guid = [[ParentGuid]]', N'', N'0', N'', 0, -1, N'', N'', N'', N'');

GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions OFF
GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions ON
GO
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (110, 1, 'efb38a30-3faf-40f3-806b-3cddcce41fb8', N'SECTORS', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid FROM SCore.Sectors AS root_hobt', N'', N'0', N'', 0, -1, N'', N'', N'', N'');
INSERT SUserInterface.DropDownListDefinitions(ID, RowStatus, Guid, Code, NameColumn, ValueColumn, SqlQuery, DefaultSortColumnName, IsDefaultColumn, DetailPageUrl, IsDetailWindowed, EntityTypeId, InformationPageUrl, GroupColumn, ColourHexColumn, ExternalSearchPageUrl) VALUES (111, 1, 'bb283689-4024-44e2-b9d2-7afc9385b728', N'MARKETS', N'Name', N'Guid', N'SELECT root_hobt.Name, root_hobt.Guid 
FROM SCore.Markets AS root_hobt WHERE root_hobt.RowStatus NOT IN (0,254)', N'', N'0', N'', 0, -1, N'', N'', N'', N'');
GO
SET IDENTITY_INSERT SUserInterface.DropDownListDefinitions OFF
GO