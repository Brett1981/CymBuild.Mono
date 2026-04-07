## CymBuild Activity Migration from Shore Inspections ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


from common import *

def migrate_activities():

    records = fetch_activities()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SJob.Activities a
        WHERE	(a.LegacyID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['LegacyId']))
        
        if cursor.rowcount == 0:
            upsert_activity(r['JobId'], r['Email'], r['StartDate'], r['EndDate'],
                            r['InspectionType'], r['InspectionStatus'], r['Title'],
                            r['Notes'], r['PlotNo'], r['LegacyId'])

def fetch_activities():
    sql_query = """
    SELECT	ir.[Job ID] as JobId,
		m.Email, 
		ir.Date as StartDate,
		ir.[End] as EndDate,
        ISNULL(REPLACE(ir.PlotNo, N',', N''), 0) PlotNo,
		itype.InspectionType,
		istat.Type as InspectionStatus,
		LEFT(ir.[Inspection notes], 250) as Title,
		ir.[Inspection notes] as Notes,
		ir.[Inspection record ID] as LegacyId
    FROM	dbo.[tbl Inspection record] ir
	JOIN	dbo.[tbl InspectionTypes] itype on (itype.ID = ir.[Inspection type ID])
	JOIN	dbo.tlkpInspectionStatus istat on (istat.Id = ir.[InspectionStatusID])
	JOIN	dbo.ShoreJob sj on (sj.[Job ID] = ir.[Job ID])
	LEFT JOIN	dbo.Users u on (u.UserId = ir.[Surveyor ID])
	LEFT JOIN	dbo.aspnet_Membership m on (m.UserId = u.MembershipID)
    WHERE	(EXISTS 
                (
                    select 1 from SJob.JobTypes jt
                    where	(jt.Name IN ('SOCOTEC BCC', N'SOCOTEC HRB'))
                        AND	(jt.ID = sj.[App type ID])
                )
            )
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} Activities")

    return records

def upsert_activity(job_id, surveyor_email, date, end_date, activity_type, 
               activity_status, title, notes, invoice_value, legacy_id):
    
    surveyor_email = remap_user(surveyor_email)
    invoice_value = float(invoice_value.replace(",", ""))

    print (f"Adding Activity to job: {job_id} dated: {date}")

    # Get the guid for the job
    print ("    getting the job guid")
    sql_query = """
            SELECT	t.Guid FROM SJob.Jobs t WHERE LegacyId = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (job_id))

    job = cursor.fetchone()
    job_guid = job['Guid']

    # Get the guid for the Activity Status
    print ("    getting the activity status guid")
    sql_query = """
            SELECT	t.Guid FROM SJob.ActivityStatus t WHERE Name = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (activity_status))

    status = cursor.fetchone()

    if (status):
        activity_status_guid = status['Guid']
    else:
        raise Exception(f"Filed to find Activity Status: {activity_status}")

    # Get the guid for the job
    print ("    getting the activity types guid")
    sql_query = """
            SELECT	t.Guid FROM SJob.ActivityTypes t WHERE Name = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (activity_type))

    type = cursor.fetchone()

    if (type):
        activity_type_guid = type['Guid']
    else:
        raise Exception(f"Filed to find Activity Type: {activity_type}")

    # Get the guid for the suryeyor
    print ("    getting the surveyor guid")
    sql_query = """
            SELECT	t.Guid FROM SCore.Identities t WHERE EmailAddress = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   ("" if surveyor_email is None else surveyor_email))

    identity = cursor.fetchone()

    if (identity):
        identity_guid = identity['Guid']
    else:
        raise Exception(f"Filed to find Surveyor: {surveyor_email}")

    # Upsert the Job type
    sql_stmt = """
            EXEC SJob.ActivitiesUpsert %s, %s, %s, %s, %s,
                                    %s, %s, %s, %s, %s, 
                                    %s, %s, %s, %s, %s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (job_guid,
                     identity_guid,
                     date,
                     end_date,
                     activity_type_guid,
                     activity_status_guid,
                     "" if title is None else title,
                     "" if notes is None else notes,
                     identity_guid,
                     False,
                     EMPTY_GUID,
                     EMPTY_GUID,
                     0,
                     invoice_value,
                     record_guid))
    
    # Set the legacy ID
    sql_stmt = """
            UPDATE SJob.Activities SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       LEGACY_SYSTEM_ID,
                       record_guid
                   ))
    
    return record_guid
