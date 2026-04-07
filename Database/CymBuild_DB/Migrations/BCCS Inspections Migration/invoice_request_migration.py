## CymBuild Invoice Request Migration from Shore Inspections ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


from common import *

def migrate_invoice_requests():

    records = fetch_invoice_requests()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SFin.InvoiceRequests a
        WHERE	(a.LegacyID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['LegacyId']))
        
        if cursor.rowcount == 0:
            upsert_invoice_request(r['JobId'], r['Email'], 
                            r['Title'], r['PlotNo'], r['LegacyId'])

def fetch_invoice_requests():
    sql_query = """
    SELECT	ir.[Job ID] as JobId,
		m.Email, 
		ir.Date as StartDate,
		LEFT(ir.[Inspection notes], 250) as Title,
		REPLACE(ir.PlotNo, N',', N'') PlotNo,
		ir.[Inspection record ID] as LegacyId
    FROM	dbo.[tbl Inspection record] ir
	LEFT JOIN	dbo.[tbl InspectionTypes] AS nitype ON (nitype.ID = ir.NextInspectionTypeID)
	JOIN	dbo.ShoreJob sj on (sj.[Job ID] = ir.[Job ID])
	LEFT JOIN	dbo.Users u on (u.UserId = ir.[Surveyor ID])
	LEFT JOIN	dbo.aspnet_Membership m on (m.UserId = u.MembershipID)
    WHERE	(EXISTS 
                (
                    select 1, id from SJob.JobTypes jt
                    where	(jt.Name IN ('SOCOTEC BCC', N'SOCOTEC HRB'))
                        AND	(jt.ID = sj.[App type ID])
                )
            )
		AND	(nitype.InspectionType = N'Invoice')
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} Invoice Requests")

    return records

def upsert_invoice_request(job_id, surveyor_email, title, plot_no, legacy_id):
    surveyor_email = remap_user(surveyor_email)

    print (f"Adding Invoice Request to job: {job_id}")

    # Get the guid for the job
    sql_query = """
            SELECT	t.Guid FROM SJob.Jobs t WHERE LegacyId = %s 
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (job_id))

    job = cursor.fetchone()
    job_guid = job['Guid']

    # Get the guid for the suryeyor
    print ("    getting the surveyor")
    sql_query = """
            SELECT	t.Guid FROM SCore.Identities t WHERE EmailAddress = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (surveyor_email))

    identity = cursor.fetchone()

    if (identity):
        identity_guid = identity['Guid']
    else:
        raise Exception(f"Filed to find surveyor: {surveyor_email}")

    # Upsert the Invoice Request
    sql_stmt = """
            EXEC SFin.InvoiceRequestUpsert %s, %s, %s, %s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (job_guid,
                     identity_guid,
                     "" if title is None else title,
                     record_guid))
    
    # Set the legacy ID
    sql_stmt = """
            UPDATE SFin.InvoiceRequests SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       LEGACY_SYSTEM_ID,
                       record_guid
                   ))
    
    upsert_invoice_request_item(record_guid, legacy_id, plot_no)
    
    return record_guid

def upsert_invoice_request_item(invoice_request_guid, legacy_id, net):
    print(" adding the Invoice Request Item")

    if (net is None): 
        net = 0
    else:    
        net = net.replace(",", "")

    # Get the guid for the activity
    print(" get the activity")
    sql_query = """
            SELECT	t.Guid FROM SJob.Activities t WHERE LegacyId = %s  
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (legacy_id))

    activity = cursor.fetchone()
    activity_guid = activity['Guid']

    # Upsert the Invoice Request ?Item
    sql_stmt = """
            EXEC SFin.InvoiceRequestItemsUpsert %s, %s, %s, %s, %s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (invoice_request_guid,
                     EMPTY_GUID,
                     activity_guid,
                     net,
                     record_guid))
    
    return record_guid
