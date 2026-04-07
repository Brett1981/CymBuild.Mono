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


def migrate_jobs():

    records = fetch_jobs()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SJob.Jobs a
        WHERE	(a.LegacyID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['JobID']))
        
        if cursor.rowcount == 0:
            upsert_job(r['job_type'], r['UPRN'], r['ClientId'], r['AgentId'], r['email'], r['JobTitle'], r['NDA'], r['StartDate'], r['Completed'],
                             r['Cancelled'], r['ContractValue'], r['Fee'], r['ArchiveReferenceLink'], r['ArchiveBoxReference'],
                             r['CreatedOn'], r['ExtProjRef'], r['CompleteForReview'], r['ReviewedDateTime'], r['AppFormReceived'],
                             "", r['ClientAppointmentReceived'], r['FirstName'], r['Surname'], r['Phone'], r['Mobile'], r['JobID'])

def fetch_jobs():
    sql_query = """
    SELECT	CASE jt.Name WHEN N'SOCOTEC BCC' THEN N'BCCS (Non HRB)' ELSE jt.Name END as job_type,
		sj.UPRN,
		sj.[Client ID] as ClientId,
		sj.[Agent ID] as AgentId,
		m.email,
		sj.[Job title] as JobTitle,
		sj.NDA, 
		sj.StartDate,
		sj.Completed,
		sj.Cancelled,
		sj.[Contract Value] as ContractValue,
		sj.Fee,
		sj.Archive,
		sj.ArchiveBoxNumber,
		sj.CreatedOn,
		sj.ExtProjRef,
		sj.CompleteForReview,
		sj.ProjectReviewChecked,
		sj.AppFormNotReceived,
		sj.VerifyAppointmentsMade,
		sj.Archive AS ArchiveReferenceLink,
		sj.ArchiveBoxNumber AS ArchiveBoxReference,
		sj.ProjectReviewChecked AS ReviewedDateTime,
		NULL AS AppFormReceived,
		sj.WAR AS ClientAppointmentReceived,
        sj.FirstName,
		sj.Surname,
		sj.Phone,
		sj.Mobile,
		sj.[Job ID] as JobID
    FROM	dbo.ShoreJob sj
	JOIN	SJob.JobTypes jt on (jt.ID = sj.[App type ID])
	JOIN	dbo.Users u on (u.UserId = sj.[Surveyor ID])
	LEFT JOIN	dbo.aspnet_Membership m on (m.UserId = u.MembershipID)
    WHERE	(EXISTS 
                (
                    select 1 from SJob.JobTypes jt
                    where	(jt.Name IN (N'SOCOTEC BCC', N'SOCOTEC HRB'))
                        AND	(jt.ID = sj.[App type ID])
                )
            )
    ORDER BY  sj.[Job ID] 
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} Jobs")

    return records


def upsert_job(job_type, uprn, client_account, agent_account, 
               surveyor, job_description, is_subject_to_nda, job_started,
                job_completed, job_cancelled, value_of_work, agreed_fee, archive_reference_link, archive_box_reference,
                 created_on, external_reference, is_complete_for_review, review_date_time_utc, app_form_received, 
                  purchase_order_number, client_appointment_received, firstname, surname, phone, mobile, legacy_id):
    
    print (f"Adding Job: {legacy_id}")
    
    surveyor = remap_user(surveyor)
    
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
            SELECT	t.Guid FROM SJob.Properties t WHERE LegacyID = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (uprn))

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
    

    if (client_account == 18886):
        print ("    replacing the TBC account with blank")
        client_account = -1

    # Client Account
    print ("    getting the client")
    client_account_guid, client_account_address_guid, client_account_contact_guid = get_legacy_account_details(client_account)

    # Agent Account
    print ("    getting the agent")
    agent_account_guid, agent_account_address_guid, agent_account_contact_guid = get_legacy_account_details(agent_account)

    # Finance Account
    print ("    getting the finance account")
    finance_account_guid, finance_account_address_guid, finance_account_contact_guid = get_legacy_account_details(client_account)    
        

    firstname = "" if firstname is None else firstname
    surname = "" if surname is None else surname

    if (firstname != ""):
        client_account_contact_guid = upsert_contact(firstname, surname, firstname + " " + surname, client_account_guid, EMPTY_GUID, None, EMPTY_GUID, is_person=True)
        finance_account_contact_guid = client_account_contact_guid
    
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
                    agent_account_guid,
                    agent_account_address_guid,
                    agent_account_contact_guid,
                    finance_account_guid,
                    finance_account_address_guid,
                    finance_account_contact_guid,
                    identity_guid,
                    "" if job_description is None else job_description,
                    is_subject_to_nda,
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
                    "" if archive_reference_link is None else archive_reference_link,
                    "" if archive_box_reference is None else archive_box_reference,
                    created_on,
                    "" if external_reference is None else external_reference,
                    is_complete_for_review,
                    EMPTY_GUID,
                    review_date_time_utc,
                    False if app_form_received is None else app_form_received,
                    0,
                    EMPTY_GUID,
                    None,
                    purchase_order_number,
                    EMPTY_GUID,
                    EMPTY_GUID,
                    0 if value_of_work is None else value_of_work,
                    False if client_appointment_received is None else True,
                    EMPTY_GUID,
                    None,
                    record_guid))
    
    if (legacy_id is not None):
        # Set the legacy ID
        print ("    setting the legacy id")
        sql_stmt = """
                UPDATE SJob.Jobs SET LegacyId = %s, LegacySystemID = %s, Number = %s WHERE Guid = %s
            """
        
        cursor = dest_conn.cursor()
        cursor.execute(sql_stmt, 
                    (
                        legacy_id,
                        LEGACY_SYSTEM_ID,
                        "BCCS-" + str(legacy_id),
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
            upsert_job_memo(r['JobID'], r['Memo'], r['Date'], r['Surveyor'], r['JobID'])
            
def fetch_job_memos():
    sql_query = """
    SELECT	tm.id,
		tm.Memo,
		tm.Date,
		m.Email AS Surveyor,
		sj.[Job ID] as JobID
    FROM	dbo.[tbl Memo] AS tm 
	JOIN	dbo.ShoreJob sj on (sj.[Job ID] = tm.[Job ID])
	JOIN	dbo.Users u on (u.UserId = sj.[Surveyor ID])
	LEFT JOIN	dbo.aspnet_Membership m on (m.UserId = u.MembershipID)
    WHERE	(EXISTS 
                (
                    select 1 from SJob.JobTypes jt
                    where	(jt.Name IN (N'SOCOTEC BCC', N'SOCOTEC HRB'))
                        AND	(jt.ID = sj.[App type ID])
                )
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
            SELECT	t.Guid FROM SJob.Jobs t WHERE LegacyId = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (job))

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
            UPDATE SJob.JobMemos SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       LEGACY_SYSTEM_ID,
                       record_guid
                   ))
    
    return record_guid
