## CymBuild Job Migration from Shore Inspections ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


from common import *
from account_migration import upsert_contact
from datetime import datetime

def create_empty_jobs(count, type_name):

    for n in range (0, count):
        upsert_job(type_name, 0, -1, -1, "", "", False, datetime.now(), None,
                             None, 0, 0, "", "",
                             datetime.now(), "", False, None, False,
                             "", False, "", "", "", "", None)


def migrate_jobs(as_skeleton):

    records = fetch_jobs()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SJob.Jobs a
        WHERE	(a.LegacyID = %s) and (a.LegacySystemID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['legacy_id'],
                     LEGACY_SYSTEM_ID))
        
        if cursor.rowcount == 0:
            if (as_skeleton):
                upsert_job(r['job_type'], 0, -1, "", -1, "", 
                            "", r['description'], r['start_date'], r['job_completed'], r['job_cancelled'], r['value_of_work'], 
                            r['fee_value'], r['job_created'], r['job_number'], None,
                            None, None, 
                            r['legacy_id'])
            else:
                upsert_job(r['job_type'], r['uprn'], r['client_id'], r['client_code'], r['finance_id'], r['finance_code'], 
                            r['email'], r['description'], r['start_date'], r['job_completed'], r['job_cancelled'], r['value_of_work'], 
                            r['fee_value'], r['job_created'], r['job_number'], r['planned_start_date'], 
                            r['Ext_Construction_Value_Name'], r['Ext_Construction_Value_Value'], 
                            r['legacy_id'])

def fetch_jobs():
    sql_query = """
    SELECT	N'BCCS (HRB)' AS job_type,
		ma.Mailing_Address_ID AS uprn,
		client.organisation_id AS client_id,
		client.code AS client_code,
		finance.organisation_id AS finance_id,
		finance.code AS finance_code,
		project_manager.email,
		p.description,
		p.start_date,
		CASE WHEN ps.Name = N'Complete' THEN p.Completion_Date ELSE NULL END AS job_completed,
		CASE WHEN ps.Name = N'Cancelled' THEN p.Completion_Date ELSE NULL END AS job_cancelled,
		pu.Construction_Value as value_of_work,
		p.fee_value,
		p.Created_Date as job_created,		
		p.Project_ID as legacy_id,
		p.Project_Code as job_number,
		p.Planned_Start_Date as planned_start_date,
		p.Total_Fee_Billed,
		p.Total_Fee_Invoiced,
		ecv.Name Ext_Construction_Value_Name, 
		ecv.Value Ext_Construction_Value_Value
FROM	dbo.Project AS p
JOIN	dbo.Project_Status AS ps ON (ps.Project_Status_ID = p.Project_Status_ID)
JOIN	dbo.Project_UDF AS pu ON (pu.Project_ID = p.Project_ID)
JOIN	dbo.EXT_Cost_Centre AS ecc ON (ecc.EXT_Cost_Centre_ID = pu.EXT_Cost_Centre_ID)
LEFT JOIN	dbo.EXT_Construction_Value AS ecv ON (ecv.EXT_Construction_Value_ID = pu.EXT_Construction_Value_ID)
JOIN	dbo.Enquiry AS e ON (e.Enquiry_ID = p.Enquiry_ID)
JOIN	dbo.Enquiry_Status AS es ON (es.Enquiry_Status_ID = e.Enquiry_Status_ID)
JOIN	dbo.Entity AS e2 ON e2.Global_ID = p.Global_ID
JOIN	dbo.Entity_Finance AS ef ON (ef.Entity_Identifier = e2.Entity_Identifier) AND (ef.Entity_Class_ID = e2.Entity_Class_ID)
JOIN	dbo.EXT_Building_Over AS ebo ON (ebo.EXT_Building_Over_ID = pu.EXT_Building_Over_ID)
JOIN	dbo.Mailing_Address AS ma ON (ma.Entity_Class_ID = e2.Entity_Class_ID) AND (ma.Entity_Identifier = e2.Entity_Identifier)
OUTER APPLY
(
	SELECT	o.Name, o.Organisation_ID, ebc.Code
	FROM	dbo.Entity_Organisations AS eo 
	JOIN	dbo.Organisation_Role AS oro ON (oro.Organisation_Role_ID = eo.Organisation_Role_ID)
	JOIN	dbo.Organisation AS o ON (o.Organisation_ID = eo.Organisation_ID)
	LEFT JOIN	dbo.EXT_BYL_Client AS ebc ON (ebc.Organisation_ID = o.Organisation_ID)
	WHERE	(eo.Entity_Identifier = e2.Entity_Identifier) AND (eo.Entity_Class_ID = e2.Entity_Class_ID)
		AND	(oro.Name =  N'Client')

) client
OUTER APPLY
(
	SELECT	o.Name, o.Organisation_ID, ebc.Code
	FROM	dbo.Entity_Organisations AS eo 
	JOIN	dbo.Organisation_Role AS oro ON (oro.Organisation_Role_ID = eo.Organisation_Role_ID)
	JOIN	dbo.Organisation AS o ON (o.Organisation_ID = eo.Organisation_ID)
	LEFT JOIN	dbo.EXT_BYL_Client AS ebc ON (ebc.Organisation_ID = o.Organisation_ID)
	WHERE	(eo.Entity_Identifier = e2.Entity_Identifier) AND (eo.Entity_Class_ID = e2.Entity_Class_ID)
		AND	(oro.Name =  N'Invoice Recipient')
) finance
OUTER APPLY 
(
	SELECT	c.Surname,
			c.Forename,
			Email.Address_or_Number AS Email
	FROM 	dbo.Entity_Contacts AS ec 
	JOIN	dbo.Contact AS c ON (c.Contact_ID = ec.Contact_ID)
	JOIN	dbo.Contact_Role AS cr ON (cr.Contact_Role_ID = ec.Contact_Role_ID)
	OUTER APPLY
	(
		SELECT	ccm.Address_or_Number
		FROM	dbo.Contacts_Contact_Methods AS ccm
		JOIN	dbo.Contact_Method AS cm ON (cm.Contact_Method_ID = ccm.Contact_Method_ID)
		WHERE	(ccm.Contact_ID = c.Contact_ID)
			AND	(cm.Name = N'Email')
	) AS Email
	WHERE	(ec.Entity_Identifier = e2.Entity_Identifier) AND (ec.Entity_Class_ID = e2.Entity_Class_ID)
		AND	(cr.Name = N'Project Manager')
) project_manager
WHERE	(p.name  LIKE N'HRB%')
	AND	(project_manager.Email = N'David.Warren@socotec.co.uk')
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} Jobs")

    return records


def upsert_job(job_type, uprn, client_id, client_code, finance_id, finance_code, 
               surveyor_email, job_description, job_started, job_completed, job_cancelled, value_of_work, 
               agreed_fee, created_on, job_number, planned_start_date, ext_construction_value_name,  
               ext_construction_value_value, legacy_id):
    
    print (f"Adding Job: {legacy_id}")
    
    surveyor = remap_user(surveyor_email)
    
    # Get the guid for the job type
    print ("    getting the job type")
    sql_query = """
            SELECT	t.Guid FROM SJob.JobTypes t WHERE Name = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (job_type))

    jt = cursor.fetchone()

    if (jt):
        job_type_guid = jt['Guid']
    else:
        raise Exception(f"Filed to find Job Type: {job_type}")

    # Get the guid for the structure
    print ("    getting the structure")
    sql_query = """
            SELECT	t.Guid 
            FROM    SJob.Properties t 
            WHERE   (LegacyID = %s) 
                AND ((LegacySystemID = %s) or (LegacySystemID = -1))
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (uprn, 
                   LEGACY_SYSTEM_ID))

    structure = cursor.fetchone()
    structure_guid = structure['Guid']

    # Get the guid for the suryeyor
    print ("    getting the surveyor")
    sql_query = """
            SELECT	t.Guid FROM SCore.Identities t WHERE EmailAddress = %s  
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   ("" if surveyor is None else surveyor))

    identity = cursor.fetchone()

    if (identity):
        identity_guid = identity['Guid']
    else:
        raise Exception(f"Filed to find Surveyor: {surveyor}")
    

    # Client Account
    print ("    getting the client")
    client_account_guid, client_account_address_guid, client_account_contact_guid = get_legacy_account_details(client_id, client_code)

    # Finance Account
    print ("    getting the finance account")
    finance_account_guid, finance_account_address_guid, finance_account_contact_guid = get_legacy_account_details(client_id, client_code)

    #firstname = "" if firstname is None else firstname
    #surname = "" if surname is None else surname

    #if (firstname != ""):
    #    client_account_contact_guid = upsert_contact(firstname, surname, firstname + " " + surname, client_account_guid, EMPTY_GUID, None, EMPTY_GUID)
    #    finance_account_contact_guid = client_account_contact_guid
    
    # Upsert the Job 
    sql_stmt = """
            EXEC SJob.JobsUpsert    @OrganisationalUnitGuid=%s, @JobTypeGuid=%s, @UprnGuid=%s, @ClientAccountGuid=%s, @ClientAddressGuid=%s, 
                                    @ClientContactGuid=%s, @AgentAccountGuid=%s, @AgentAddressGuid=%s, @AgentContactGuid=%s, 
                                    @FinanceAccountGuid=%s, @FinanceAddressGuid=%s, @FinanceContactGuid=%s, @SurveyorGuid=%s, 
                                    @JobDescription=%s, @IsSubjectToNDA=%s, @JobStarted=%s, @JobCompleted=%s, 
                                    @JobCancelled=%s, @ValueofWorkGuid=%s, @AgreedFee=%s, @RibaStage1Fee=%s, @RibaStage2Fee=%s, 
                                    @RibaStage3Fee=%s, @RibaStage4Fee=%s, @RibaStage5Fee=%s, @RibaStage6Fee=%s, @RibaStage7Fee=%s, 
                                    @PreConstructionStageFee=%s, @ConstructionStageFee=%s, @ArchiveReferenceLink=%s, 
                                    @ArchiveBoxReference=%s, @CreatedOn=%s, @ExternalReference=%s, @IsCompleteForReview=%s, 
                                    @ReviewedByUserGuid=%s, @ReviewDateTimeUTC=%s, @AppFormReceived=%s, @FeeCap=%s, @CurrentRibaStageGuid=%s, 
                                    @JobDormant=%s, @PurchaseOrderNumber=%s, @ContractGuid=%s, @ProjectGuid=%s, @ValueOfWork=%s, 
                                    @ClientAppointmentReceived=%s, @AppointedFromStageGuid=%s, @DeadDate=%s, @Guid=%s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (TARGET_ORGANISATIONAL_UNIT_GUID, 
                    job_type_guid,
                    structure_guid,
                    client_account_guid,
                    client_account_address_guid,
                    client_account_contact_guid,
                    EMPTY_GUID,
                    EMPTY_GUID,
                    EMPTY_GUID,
                    finance_account_guid,
                    finance_account_address_guid,
                    finance_account_contact_guid,
                    identity_guid,
                    "" if job_description is None else job_description,
                    False,
                    job_started,
                    job_completed,
                    job_cancelled,
                    EMPTY_GUID,
                    0 if agreed_fee is None else agreed_fee,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    0,
                    "", # archive_reference_link,
                    "", # else archive_box_reference,
                    created_on,
                    "", # external_reference,
                    False,
                    EMPTY_GUID,
                    None,
                    False, # app_form_received,
                    0,
                    EMPTY_GUID,
                    None,
                    "", #purchase_order_number,
                    EMPTY_GUID,
                    EMPTY_GUID,
                    0 if value_of_work is None else value_of_work,
                    False, # client_appointment_received,
                    EMPTY_GUID,
                    None,
                    record_guid))
    
    if (legacy_id is not None):
        # Set the legacy ID
        print ("    setting the legacy id")
        sql_stmt = """
                UPDATE SJob.Jobs SET LegacyId = %s, Number = %s, LegacySystemId = %s WHERE Guid = %s
            """
        
        cursor = dest_conn.cursor()
        cursor.execute(sql_stmt, 
                    (
                        legacy_id,
                        "SOCHRB-" + str(job_number),
                        LEGACY_SYSTEM_ID,
                        record_guid
                    ))
    
    return record_guid


def migrate_job_memos():
    records = fetch_job_memos()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SJob.JobMemos a
        WHERE	(a.LegacyID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['id']))
        
        if cursor.rowcount == 0:
            upsert_job_memo(r['Project_ID'], r['Notes'], r['Date'], r['Surveyor'], r['id'])
            
def fetch_job_memos():
    sql_query = """
    SELECT	p.Project_ID,
            en.Last_Update_Time as Date,
            en.Last_Update_User,
            u.User_Logon + N'@socotec.co.uk' AS Surveyor,
            en.Notes,
			en.Entity_Notes_ID as id
    FROM	dbo.Entity_Notes AS en 
    JOIN	dbo.Entity AS e2 ON (e2.Entity_Class_ID = en.Entity_Class_ID) AND (e2.Entity_Identifier = en.Entity_Identifier) 
    JOIN	dbo.Project AS p ON (e2.Global_ID = p.Global_ID)
    JOIN	dbo.Contact AS u ON (u.Contact_ID = en.Last_Update_User)
    WHERE	(p.name  LIKE N'HRB%')
        AND
        EXISTS 
        (
            SELECT	1
            FROM 	dbo.Entity_Contacts AS ec 
            JOIN	dbo.Contact AS c ON (c.Contact_ID = ec.Contact_ID)
            JOIN	dbo.Contact_Role AS cr ON (cr.Contact_Role_ID = ec.Contact_Role_ID)
            OUTER APPLY
            (
                SELECT	ccm.Address_or_Number
                FROM	dbo.Contacts_Contact_Methods AS ccm
                JOIN	dbo.Contact_Method AS cm ON (cm.Contact_Method_ID = ccm.Contact_Method_ID)
                WHERE	(ccm.Contact_ID = c.Contact_ID)
                    AND	(cm.Name = N'Email')
            ) AS Email
            WHERE	(ec.Entity_Identifier = e2.Entity_Identifier) AND (ec.Entity_Class_ID = e2.Entity_Class_ID)
                AND	(cr.Name = N'Project Manager')
                AND	(email.Address_or_Number = N'David.Warren@socotec.co.uk')
        ) 
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} Job Memos")

    return records

def upsert_job_memo(job, memo, date, surveyor, legacy_id):
    
    print (f"Adding Job Memo: {legacy_id}")
    
    surveyor = remap_user(surveyor)
    
    # Get the guid for the job
    print ("    getting the job")
    sql_query = """
            SELECT	t.Guid 
            FROM SJob.Jobs t 
            WHERE LegacyId = %s
                 AND   LegacySystemID = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (job,
                    LEGACY_SYSTEM_ID))

    jt = cursor.fetchone()

    if (jt):
        job_guid = jt['Guid']
    else:   
        raise Exception(f"Filed to find Job: {job}")

    # Get the guid for the suryeyor
    print ("    getting the surveyor")
    sql_query = """
            SELECT	t.Guid FROM SCore.Identities t WHERE EmailAddress = %s  
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   ("" if surveyor is None else surveyor))

    identity = cursor.fetchone()

    if (identity):
        identity_guid = identity['Guid']
    else:
        raise Exception(f"Filed to find Surveyor: {surveyor}")

    # Upsert the Job 
    sql_stmt = """
            EXEC SJob.JobMemosUpsert    @JobGuid=%s, @Memo=%s, @CreatedDateTimeUTC=%s, @CreatedByUserGuid=%s, @Guid=%s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (job_guid, 
                    memo,
                    date,
                    identity_guid,
                    record_guid))
    
    # Set the legacy ID
    print ("    setting the legacy id")
    sql_stmt = """
            UPDATE SJob.JobMemos SET LegacyId = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       record_guid
                   ))
    
    return record_guid
