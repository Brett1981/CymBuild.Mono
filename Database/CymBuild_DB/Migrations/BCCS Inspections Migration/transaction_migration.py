## CymBuild Transactions Migration from Shore Inspections ##
from invoice_request_migration import upsert_invoice_request, upsert_invoice_request_item

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


from common import *

def migrate_transactions():

    records = fetch_transactions()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SFin.Transactions a
        WHERE	(a.LegacyID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['LegacyId']))
        
        if cursor.rowcount == 0:
            upsert_transactions(r['StartDate'], r['ClientID'], r['JobId'], r['Email'], 
                            r['Title'], r['PlotNo'], r['LegacyId'])

def fetch_transactions():
    sql_query = """
    SELECT	ir.[Job ID] as JobId,
		CASE WHEN m.Email = N'Ryanfitz1981@gmail.com' then N'Ryan.Fitzgerald@socotec.co.uk' ELSE m.Email END as Email, 
		ir.Date as StartDate,
		LEFT(ir.[Inspection notes], 250) as Title,
		REPLACE(ir.PlotNo, N',', N'') PlotNo,
		CASE WHEN sj.[Client ID] = -1 THEN sj.[Agent ID] ELSE sj.[Client ID] END AS ClientID,
		ir.[Inspection record ID] as LegacyId
    FROM	dbo.[tbl Inspection record] ir
	LEFT JOIN	dbo.[tbl InspectionTypes] AS nitype ON (nitype.ID = ir.NextInspectionTypeID)
	JOIN	dbo.ShoreJob sj on (sj.[Job ID] = ir.[Job ID])
	JOIN	dbo.Users u on (u.UserId = ir.[Surveyor ID])
	JOIN	dbo.aspnet_Membership m on (m.UserId = u.MembershipID)
    WHERE	(EXISTS 
                (
                    select 1, id from SJob.JobTypes jt
                    where	(jt.Name IN ('SOCOTEC BCC', N'SOCOTEC HRB'))
                        AND	(jt.ID = sj.[App type ID])
                )
            )
		AND	(nitype.InspectionType = N'Invoice Sent')
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    return records

def upsert_transactions(date, client_id, job_id, surveyor_email, title, plot_no, legacy_id):

    surveyor_email = remap_user(surveyor_email)

    # Get the guid for the transaction type
    sql_query = """
            SELECT	t.Guid FROM SFin.TransactionTypes t WHERE Name = %s  
        """
    
    invoice_request_guid = upsert_invoice_request(job_id, surveyor_email, title, plot_no, legacy_id)
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   ("Invoice"))

    transaction_type = cursor.fetchone()
    transaction_type_guid = transaction_type['Guid']


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
    sql_query = """
            SELECT	t.Guid FROM SCore.Identities t WHERE EmailAddress = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (surveyor_email))

    identity = cursor.fetchone()
    identity_guid = identity['Guid']

    # Client Account
    print ("    getting the client")
    if (client_id == 18886 or client_id == -1):
        raise Exception (f"The client account is not valid for a financian transaction. Client account: {client_id}, Job: {job_id}")
    else:    
        account_guid, client_account_address_guid, client_account_contact_guid = get_legacy_account_details(client_id)


    # Upsert the Invoice Request
    sql_stmt = """
            EXECUTE [SFin].[TransactionsUpsert] @AccountGuid=%s, @JobGuid=%s, @TransactionTypeGuid=%s, 
                                                        @Date=%s, @PurchaseOrderNumber=%s, @SageTransactionReference=%s, @OrganisationalUnitGuid=%s, 
                                                        @CreatedByUserGuid=%s, @SurveyorGuid=%s, @CreditTermsGuid=%s, @Guid=%s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (account_guid,
                     job_guid,
                     transaction_type_guid,
                     date,
                     "",
                     "",
                     TARGET_ORGANISATIONAL_UNIT_GUID,
                     identity_guid,
                     identity_guid,
                     EMPTY_GUID,
                     record_guid))
    
    # Set the legacy ID
    sql_stmt = """
            UPDATE SFin.Transactions SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       LEGACY_SYSTEM_ID,
                       record_guid
                   ))
    
    upsert_transaction_detail(record_guid, legacy_id, plot_no, invoice_request_guid)
    
    return record_guid

def upsert_transaction_detail(transaction_guid, legacy_id, net, invoice_request_guid=None):
    
    if (invoice_request_guid):
        invoice_request_item_guid = upsert_invoice_request_item(invoice_request_guid, legacy_id, net)

        sql_query = """
            SELECT	t.ID FROM SFin.InvoiceRequestItems t WHERE Guid = %s 
        """
    
        cursor = dest_conn.cursor()
        cursor.execute(sql_query,
                    (invoice_request_item_guid))

        invoice_request_item = cursor.fetchone()
        invoice_request_item_id = invoice_request_item['ID']
    else:
        invoice_request_item_id = -1
    
    # Get the guid for the activity
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
            EXECUTE [SFin].[TransactionDetailsUpsert] @TransactionGuid=%s, @MilestoneGuid=%s, @ActivityGuid=%s, @Net=%s, 
                                                            @Vat=%s, @Gross=%s, @VatRate=%s, @Description=%s, @JobPaymentStageGuid=%s, @Guid=%s
        """
    
    record_guid = uuid.uuid4()



    net = float(0.0) if net is None else net.replace(",", "")
    vat = float(net) * float(0.2)
    gross = float(net) + float(vat)

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (transaction_guid,
                     EMPTY_GUID,
                     activity_guid,
                     net,
                     vat,
                     gross,
                     20,
                     "",
                     EMPTY_GUID,
                     record_guid))
    
    # Set the legacy ID
    sql_stmt = """
            UPDATE SFin.TransactionDetails SET InvoiceRequestItemId = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       invoice_request_item_id,
                       record_guid
                   ))

def migrate_finance_memos():

    records = fetch_finance_memos()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SFin.FinanceMemo a
        WHERE	(a.LegacyID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['LegacyId']))
        
        if cursor.rowcount == 0:
            upsert_finance_memos(r['Date'], r['JobID'], r['Memo'], r['Email'], r['LegacyId'])

def fetch_finance_memos():
    sql_query = """
    SELECT	im.Date,
		im.ShoreJobID AS JobID,
		im.Memo,
		m.Email,
        m.Email, 
        im.ID as LegacyId
    FROM	dbo.InvoiceMemo AS im
    JOIN	dbo.ShoreJob sj on (sj.[Job ID] = im.ShoreJobID)
    LEFT JOIN	dbo.Users u on (u.UserId = im.UserID)
    LEFT JOIN	dbo.aspnet_Membership m on (m.UserId = u.MembershipID)
    WHERE	(EXISTS 
                    (
                        select 1, id from SJob.JobTypes jt
                        where	(jt.Name IN ('SOCOTEC BCC', N'SOCOTEC HRB'))
                            AND	(jt.ID = sj.[App type ID])
                    )
                )
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    return records

def upsert_finance_memos(date, job_id, memo, surveyor_email, legacy_id):
    surveyor_email = remap_user(surveyor_email)

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
        raise Exception(f"Filed to find Surveyor: {surveyor_email}")

    # Upsert the Invoice Request
    sql_stmt = """
            EXECUTE [SFin].[FinanceMemoUpsert] @AccountGuid=%s, @JobGuid=%s, @TransactionGuid=%s, 
                                                        @Memo=%s, @UserGuid=%s, @Guid=%s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (EMPTY_GUID,
                     job_guid,
                     EMPTY_GUID,
                     memo,
                     identity_guid,
                     record_guid))
    
    # Set the legacy ID
    sql_stmt = """
            UPDATE SFin.FinanceMemo SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       LEGACY_SYSTEM_ID,
                       record_guid
                   ))
   
    return record_guid
