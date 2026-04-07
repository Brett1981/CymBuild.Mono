## CymBuild Migration tool Common ##

__author__ = "Richard Brindley"
__copyright__ = "Copyright 2024, Socotec UK"
__version__ = "1.0.1"


import pymssql, uuid
from config import *

LEGACY_SYSTEM_ID = -1

source_conn = pymssql.connect(
    server=SOURCE_SERVER,
    database=SOURCE_DATABASE,
    as_dict=True
)  

dest_conn = pymssql.connect(
    server=DESTINATION_SERVER,
    database=DESTINATION_DATABASE,
    as_dict=True
)  

EMPTY_GUID = '00000000-0000-0000-0000-000000000000'

def get_legacy_system_id():
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

def get_legacy_account_details(legacy_account_id):
    if (not legacy_account_id):
        return EMPTY_GUID, EMPTY_GUID, EMPTY_GUID

    # Get the guid for the account
    sql_query = """
            SELECT	t.Guid 
            FROM SCrm.Accounts t 
            WHERE (t.LegacyId = %s)   
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (legacy_account_id))

    account = cursor.fetchone()

    if (account):
        account_guid = account['Guid']
    else:
        raise Exception(f"Filed to find CRM Account with legacy ID: {legacy_account_id}")

    # Get the guid for the account_address
    sql_query = """
            SELECT	aa.Guid 
            FROM    SCrm.AccountAddresses aa
            JOIN    SCrm.Accounts a on (a.ID = aa.AccountId)
            JOIN    SCrm.Addresses ad on (ad.Id = aa.AddressId)
            WHERE   (a.LegacyId = %s) AND (ad.LegacyId = %s)  
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (legacy_account_id, 
                    legacy_account_id))

    account_address = cursor.fetchone()

    if (account_address):
        account_address_guid = account_address['Guid']
    else:
        raise Exception(f"Filed to find CRM Address with legacy ID: {legacy_account_id}")

    # Get the guid for the account_contact
    sql_query = """
            SELECT	ac.Guid 
            FROM    SCrm.AccountContacts ac
            JOIN    SCrm.Accounts a on (a.ID = ac.AccountId)
            JOIN    SCrm.Contacts c on (c.Id = ac.ContactId)
            WHERE   (a.LegacyId = %s) AND (c.LegacyId = %s)  
        """
    
    cursor = dest_conn.cursor()
    cursor.execute(sql_query,
                   (legacy_account_id, 
                    legacy_account_id))

    account_contact = cursor.fetchone()

    if (account_contact):
        account_contact_guid = account_contact['Guid']
    else:   
        raise Exception(f"Filed to find CRM Contact with legacy ID: {legacy_account_id}")

    return account_guid, account_address_guid, account_contact_guid

def remap_user(user_email):
    if (user_email):
        if (user_email.lower() == "loverton@wemakeshore.co.uk"):
            return "lynn.overton@socotec.co.uk"
        elif (user_email.lower() == "ryanfitz1981@gmail.com"):
            return "ryan.fitzgerald@socotec.co.uk"
        elif (user_email.lower() == "ryan.fitzgerald1@socotec.co.uk"):
            return "ryan.fitzgerald@socotec.co.uk"
        elif (user_email.lower() == "nfenn@wemakeshore.co.uk"):
            return "neil.fenn@socotec.co.uk"
        elif (user_email.lower() == "ngoodall@wemakeshore.co.uk"):
            return "neil.goodall@socotec.co.uk"
        else: 
            return user_email
    else:
        return ""
