## CymBuild Migration tool Common ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


import pymssql, uuid
from config import *

LEGACY_SYSTEM_ID = -1

print ("Building source connection.")
source_conn = pymssql.connect(
    server=SOURCE_SERVER,
    database=SOURCE_DATABASE,
    as_dict=True,
    tds_version='7.0'
)  

print ("Building destination connection.")
dest_conn = pymssql.connect(
    server=DESTINATION_SERVER,
    database=DESTINATION_DATABASE,
    as_dict=True
)  

EMPTY_GUID = '00000000-0000-0000-0000-000000000000'

def get_legacy_system_id():
    print("Getting legacy system ID")

    sql_query = """
            SELECT	t.ID 
            FROM SCore.LegacySystems t 
            WHERE (t.Guid = %s)   
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (LEGACY_SYSTEM_GUID))

    ls = cursor.fetchone()

    LEGACY_SYSTEM_ID = ls['ID']
    
def get_legacy_account_details(legacy_account_id, legacy_account_code):
    if (not legacy_account_id and not legacy_account_code):
        return EMPTY_GUID, EMPTY_GUID, EMPTY_GUID

    # Get the guid for the account
    sql_query = """
            SELECT	t.Guid 
            FROM    SCrm.Accounts t 
            WHERE   ((t.LegacyId = %s) AND (t.LegacySystemId = %s))
                OR (t.Code = %s)   
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (legacy_account_id,
                    LEGACY_SYSTEM_ID,
                    legacy_account_code))

    account = cursor.fetchone()

    if (account):
        account_guid = account['Guid']
    else:
        raise Exception(f"Filed to find CRM Account with legacy ID: {legacy_account_id}")

    # Get the guid for the account_address
    sql_query = """
            SELECT	TOP(1) aa.Guid 
            FROM    SCrm.AccountAddresses aa
            JOIN    SCrm.Accounts a on (a.ID = aa.AccountId)
            JOIN    SCrm.Addresses ad on (ad.Id = aa.AddressId)
            WHERE   (a.Guid = %s) 
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (account_guid))

    account_address = cursor.fetchone()

    account_address_guid = EMPTY_GUID

    if (account_address):
        account_address_guid = account_address['Guid']
    else:
        sql_query = """
            SELECT	TOP(1) aa.Guid 
            FROM    SCrm.AccountAddresses aa
            JOIN    SCrm.Accounts a on (a.MainAccountAddressId = aa.ID)
            WHERE   (a.Guid = %s) 
        """
    
        cursor = dest_conn.cursor()
        cursor.execute(sql_query,
                    (account_guid))

        account_address = cursor.fetchone()

    # Get the guid for the account_contact
    sql_query = """
            SELECT	TOP(1) ac.Guid 
            FROM    SCrm.AccountContacts ac
            JOIN    SCrm.Accounts a on (a.ID = ac.AccountId)
            JOIN    SCrm.Contacts c on (c.Id = ac.ContactId)
            WHERE   (a.Guid = %s) 
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (account_guid))

    account_contact = cursor.fetchone()

    account_contact_guid = EMPTY_GUID

    if (account_contact):
        account_contact_guid = account_contact['Guid']
    else:   
        sql_query = """
            SELECT	TOP(1) ac.Guid 
            FROM    SCrm.AccountContacts ac
            JOIN    SCrm.Accounts a on (a.MainAccountContactId = ac.ID)
            WHERE   (a.Guid = %s)
        """
    
        cursor = dest_conn.cursor()
        cursor.execute(sql_query,
                    (account_guid))

        account_contact = cursor.fetchone()


    return account_guid, account_address_guid, account_contact_guid

def remap_user(user_email):
    if (user_email == "loverton@wemakeshore.co.uk"):
        return "lynn.overton@socotec.co.uk"
    elif (user_email == "Ryanfitz1981@gmail.com"):
        return "ryan.fitzgerald@socotec.co.uk"
    elif (user_email == "ryan.fitzgerald1@socotec.co.uk"):
        return "ryan.fitzgerald@socotec.co.uk"
    else: 
        return user_email
