## CymBuild Transactions Migration from Shore Inspections ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


from common import *
from structure_migration import upsert_structure
from account_migration import upsert_contact
import datetime

def migrate_quotes():
    print ("Starting quote migration")

    records = fetch_quotes()

    for r in records:
        sql_query = """
        SELECT	1 Col1
        FROM	SSop.Quotes a
        WHERE	(a.LegacyID = %s)
        """

        cursor = dest_conn.cursor()
        cursor.execute(sql_query, 
                    (r['legacy_quote_item_id']))
        
        if cursor.rowcount == 0:
            upsert_quote(r['Date'], r['ClientID'], r['LinkedJobID'], r['Surveyor'], 
                            r['Overview'], r['DateSent'], r['DateAccepted'], r['DateRejected'], r['UPRN'],
                            r['ChaseDate1'], r['ChaseDate2'], r['NDA'], r['ExternalRef'],
                            False, r['ValueOfWork'], r['legacy_quote_item_id'], 
                            r['ProductName'], r['Amount'], r['AddressName'], r['AddressNumber'],
                            r['Address1'], r['Address2'], r['Address3'], r['Town'], r['County'],
                            r['Postcode'], r['QuoteNumber'], r['FirstName'], r['Surname'], r['Phone'],
                            r['Mobile'], r['Email1'])

def fetch_quotes():
    sql_query = """
    SELECT		q.[Job ID] AS QuoteNumber,
                q.UPRN AS UPRN,
                q.YRefNo AS ExternalRef,
                q.[Client ID] AS ClientID,
                am.Email AS Surveyor,
                q.Date,
                q.[Job title] AS Overview,
                q.FirstName,
                q.Surname,
                q.Phone,
                q.Mobile,
                q.Email1,
                q.[Job title] AS JobTitle,
                q.name AS AddressName,
                q.Number AS AddressNumber,
                q.[Address 1] AS Address1,
                q.[Address 2] AS Address2,
                q.[Address 3] AS Address3,
                q.Town, 
                q.County,
                q.Postcode, 
                q.NDA,
                tqt.Type ProductName,
                qi.[Q ID] AS legacy_quote_item_id,
                qi.[Value of work] AS ValueOfWork, 
                qi.ChaseDate1,
                qi.ChaseDate2,
                qi.[Date Accepted] AS DateAccepted, 
                qi.[Date Rejected] AS DateRejected,
                qi.[Date Sent] AS DateSent,
                qi.Amount,
                qi.LinkedJobID
    FROM		dbo.Quote AS q
    JOIN		dbo.QuoteItem AS qi ON (qi.[Job ID] = q.[Job ID])
    JOIN		dbo.[tbl QuoteTypes] AS tqt ON (tqt.ID = qi.[App Type ID])
    LEFT JOIN	dbo.Users AS u ON (u.UserId = q.[Surveyor ID])
    LEFT JOIN	dbo.aspnet_Membership AS am ON (u.MembershipID = am.UserId)
    WHERE		(tqt.Type IN (N'SOCOTEC BCC', N'SOCOTEC HRB'))
    """

    cursor = source_conn.cursor()
    cursor.execute(sql_query)

    records = cursor.fetchall()

    row_count = cursor.rowcount

    print (f"Found {row_count} Quotes")

    return records

def upsert_quote(date, client_id, linked_job, surveyor_email, overview, date_sent, date_accepted,
                 date_rejected, uprn, chase_date_1, chase_date_2, nda, external_reference, send_info_to_client, 
                 value_of_work, legacy_quote_item_id, product_name, net, structure_name, structure_number,
                 structure_address_1, structure_address_2, structure_address_3, structure_town, structure_county, 
                 structure_post_code, legacy_id, firstname="", surname="", phone="", mobile="", email=""):

    sql_query = """
            SELECT	t.ID FROM SJob.Jobs t WHERE LegacyId = %s  
        """
        
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (linked_job))

    linked_job_record = cursor.fetchone()

    if (linked_job_record):
        linked_job_id = linked_job_record['ID']
    else:
        linked_job_id = -1

    # Get the guid for the structure
    if (uprn > 0):
        sql_query = """
                SELECT	t.Guid FROM SJob.Properties t WHERE LegacyID = %s
            """
        
        cursor = dest_conn.cursor()
        cursor.execute(sql_query,
                    (uprn))

        structure = cursor.fetchone()

        if (structure):
            structure_guid = structure['Guid']
        else: 
            raise Exception(f"Failed to find UPRN: {uprn}")
    else:
        structure_guid = upsert_structure(structure_name, structure_number, structure_address_1, structure_address_2,
                                         structure_address_3, structure_town, structure_county, structure_post_code,
                                         False, False, 0, None, None, None, None)

    # Get the guid for the suryeyor
    sql_query = """
            SELECT	t.Guid FROM SCore.Identities t WHERE EmailAddress = %s
        """
    
    surveyor_email = remap_user(surveyor_email)

    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (surveyor_email))

    identity = cursor.fetchone()

    if (identity):
        identity_guid = identity['Guid']
    else:   
        raise Exception(f"Failed to find user: {surveyor_email}")

    # Client Account
    print ("    getting the client")
    account_guid, client_account_address_guid, client_account_contact_guid = get_legacy_account_details(client_id)

    firstname = "" if firstname is None else firstname
    surname = "" if surname is None else surname

    if (firstname != ""):
        client_account_contact_guid = upsert_contact(firstname, surname, firstname + " " + surname, account_guid, EMPTY_GUID, None, EMPTY_GUID, 
                                                     phone=phone, mobile=mobile, email=email, is_person=True)

    # Upsert the Quote
    sql_stmt = """
            EXECUTE [SSop].[QuotesUpsert]   @OrganisationalUnitGuid=%s, @QuotingUserGuid=%s, @ClientAccountGuid=%s,
                                            @ClientAddressGuid=%s, @ClientContactGuid=%s, @AgentAccountGuid=%s,
                                            @AgentAddressGuid=%s, @AgentContactGuid=%s, @ContractGuid=%s,
                                            @Date=%s, @Overview=%s, @ExpiryDate=%s, @DateSent=%s, @DateAccepted=%s,
                                            @DateRejected=%s, @RejectionReason=%s, @QuoteSourceGuid=%s,
                                            @UprnGuid=%s, @ChaseDate1=%s, @ChaseDate2=%s, @FeeCap=%s, @IsFinal=%s,
                                            @IsSubjectToNDA=%s, @ExternalReference=%s, @SendInfoToClient=%s,
                                            @SendInfoToAgent=%s, @QuotingConsultantGuid=%s, @AppointmentFromRibaStageGuid=%s,
                                            @ProjectGuid=%s, @ValueOfWork=%s, @CurrentStageGuid=%s, @DeadDate=%s,
                                            @Guid=%s
        """
    
    record_guid = uuid.uuid4()

    if (date):
        time_change = datetime.timedelta(days=60) 
        expiry_date = date + time_change 
    else:
        expiry_date = None

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (TARGET_ORGANISATIONAL_UNIT_GUID,
                     identity_guid,
                     account_guid,
                     client_account_address_guid, 
                     client_account_contact_guid,
                     EMPTY_GUID,
                     EMPTY_GUID, 
                     EMPTY_GUID, 
                     EMPTY_GUID, # @ContractGuid
                     date,
                     overview, 
                     expiry_date,
                     date_sent,
                     date_accepted,
                     date_rejected, 
                     "", # RejectionReason
                     "E646C5E3-A932-43A2-9349-AD7DA5D181D3", # QuoteSourceGuid
                     structure_guid,
                     chase_date_1,
                     chase_date_2, 
                     0, #fee_cap,
                     True if (date_sent is not None or date_accepted is not None) else False, # is_final,
                     nda,
                     external_reference,
                     send_info_to_client,
                     False, #send_info_to_agent,
                     identity_guid,
                     EMPTY_GUID,
                     EMPTY_GUID, #ProjectGuid
                     0 if value_of_work is None else value_of_work,
                     EMPTY_GUID,
                     None,
                     record_guid
                     ))
    
    # Set the legacy ID
    sql_stmt = """
            UPDATE SSop.Quotes SET Number = %s, LegacyId = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       "BCCS-" + str(legacy_id),
                       legacy_quote_item_id,
                       record_guid
                   ))
    
    upsert_quote_section(record_guid, value_of_work, product_name, net, linked_job_id, legacy_quote_item_id)
    
    return record_guid

def upsert_quote_section(quote_guid, value_of_work, product_name, net, linked_job_id, legacy_id):
    # Get the guid for the activity
    sql_query = """
            SELECT	t.Guid FROM SJob.ValuesOfWork t WHERE ID = %s 
        """
    
    if (not value_of_work):
        value_of_work = -1

    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (value_of_work))

    vow = cursor.fetchone()

    if (vow):
        value_of_work_guid = vow['Guid']
    else: 
        raise Exception(f"Failed to find Value of Work Band: {value_of_work}")


    # Upsert the Invoice Request ?Item
    sql_stmt = """
            EXECUTE [SSop].[QuoteSectionsUpsert] @QuoteGuid=%s, @RibaStageGuid=%s, @Name=%s, @Overview=%s, 
                                                @ShowProducts=%s, @ConsolidateJobs=%s, @SortOrder=%s, @NumberOfMeetings=%s, 
                                                @NumberOfSiteVisits=%s, @CombineWithSectionGuid=%s, @ValueOfWorkGuid=%s, @Guid=%s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (quote_guid,
                     "F67FE25F-50EF-4E85-B193-F5002C7A276D",
                     product_name,
                     "", #overview,
                     False, #show_products,
                     True, #consolidate_jobs,
                     1, #sort_order,
                     0, #number_of_meetings,
                     0, #number_of_site_visits,
                     EMPTY_GUID, #combine_with_section_guid,
                     value_of_work_guid,
                     record_guid))

    # Set the legacy ID
    sql_stmt = """
            UPDATE SSop.QuoteSections SET LegacyId = %s, LegacySystemID = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       legacy_id,
                       LEGACY_SYSTEM_ID,
                       record_guid
                   ))

    upsert_quote_item(record_guid, product_name, net, linked_job_id, legacy_id)

def upsert_quote_item(quote_section_guid, product_name, net, linked_job_id, legacy_id):
    product_code = "BCC-NONHRB-IMPORT"
    # Get the guid for the activity
    sql_query = """
            SELECT	t.Guid, t.Description FROM SProd.Products t WHERE t.Code = %s 
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (product_code))

    product = cursor.fetchone()

    if (product):
        product_guid = product['Guid']
        product_description = product['Description']
    else: 
        raise Exception(f"Filed to find Product: {product_code}")

    # Upsert the Invoice Request ?Item
    sql_stmt = """
            EXECUTE [SSop].[QuoteItemsUpsert] @QuoteSectionGuid=%s, @ProductGuid=%s, @Details=%s, @Net=%s, 
                                                @VatRate=%s, @DoNotConsolidateJob=%s, @SortOrder=%s, @Quantity=%s, 
                                                @Guid=%s
        """
    
    record_guid = uuid.uuid4()

    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt,
                    (quote_section_guid,
                     product_guid,
                     product_description,
                     0 if net is None else net,
                     20, #vat_rate,
                     False, #do_not_consolidate_job
                     1, #sort_order
                     1, #Quantity,
                     record_guid))

    # Set the legacy ID
    sql_stmt = """
            UPDATE SSop.QuoteItems SET CreatedJobId = %s, LegacyId = %s WHERE Guid = %s
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_stmt, 
                   (
                       linked_job_id,
                       legacy_id,
                       record_guid
                   ))
