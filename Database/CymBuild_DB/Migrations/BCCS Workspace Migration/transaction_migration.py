## CymBuild Transactions Migration from Shore Inspections ##

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
        WHERE	(a.LegacyId = %s)
            AND (a.LegacySystemId = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['legacy_id'], 
                     LEGACY_SYSTEM_ID))
        
        if cursor.rowcount == 0:
            upsert_transactions(r['Date'], r['ClientId'], r['JobId'], r['Surveyor'], 
                            r['Description'], r['Amount'], r['InvoiceNumber'], r['client_code'], r['legacy_id'])

def fetch_transactions():
    sql_query = """
    SELECT	p.Project_ID AS JobId,
            ebi.Code AS InvoiceNumber, 
            CreatedBy_Email.Address_or_Number AS Surveyor,
            ebi.Created_Date AS Date,
            ebil.Description,
            ebil.Amount,
            ebc.Organisation_ID AS ClientId,
            ebc.Code as client_code,
            ebi.EXT_BYL_Invoice_ID AS legacy_id
    FROM	dbo.EXT_BYL_Invoice AS ebi
    JOIN	dbo.Project AS p ON (p.Project_ID = ebi.Project_ID)
    JOIN	dbo.EXT_BYL_Invoice_Line AS ebil ON (ebil.EXT_BYL_Invoice_ID = ebi.EXT_BYL_Invoice_ID)
    JOIN	dbo.EXT_BYL_Client AS ebc ON (ebc.EXT_BYL_Client_ID = ebi.EXT_BYL_Client_ID)
    JOIN	dbo.Entity AS e2 ON e2.Global_ID = p.Global_ID
    OUTER APPLY
    (
        SELECT	ccm.Address_or_Number
        FROM	dbo.Contacts_Contact_Methods AS ccm
        JOIN	dbo.Contact_Method AS cm ON (cm.Contact_Method_ID = ccm.Contact_Method_ID)
        WHERE	(ccm.Contact_ID = ebi.Created_By_ID)
            AND	(cm.Name = N'Email')
    ) AS CreatedBy_Email
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

    return records

def upsert_transactions(date, client_id, job_id, surveyor_email, title, amount, invoice_number, client_code, legacy_id):
    # Get the guid for the transaction type
    sql_query = """
            SELECT	t.Guid FROM SFin.TransactionTypes t WHERE Name = %s  
        """
    
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
    account_guid, client_account_address_guid, client_account_contact_guid = get_legacy_account_details(client_id, client_code)


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
            UPDATE SFin.Transactions SET LegacyId = %s, Number = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       invoice_number,
                       record_guid
                   ))
    
    upsert_transaction_detail(record_guid, legacy_id, amount)
    
    return record_guid

def upsert_transaction_detail(transaction_guid, legacy_id, net):
    # Get the guid for the activity
    sql_query = """
            SELECT	t.Guid FROM SJob.Activities t WHERE LegacyId = %s 
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (legacy_id))

    activity = cursor.fetchone()

    if (activity): 
        activity_guid = activity['Guid']
    else:
        activity_guid = EMPTY_GUID

    # Upsert the Invoice Request ?Item
    sql_stmt = """
            EXECUTE [SFin].[TransactionDetailsUpsert] @TransactionGuid=%s, @MilestoneGuid=%s, @ActivityGuid=%s, @Net=%s, 
                                                            @Vat=%s, @Gross=%s, @VatRate=%s, @Description=%s, @JobPaymentStageGuid=%s, @Guid=%s
        """
    
    record_guid = uuid.uuid4()

    net = float(0.0) if net is None else net
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
            UPDATE SFin.FinanceMemo SET LegacyId = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       record_guid
                   ))
   
    return record_guid
