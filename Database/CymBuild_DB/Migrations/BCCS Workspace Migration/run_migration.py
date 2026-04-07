from common import *
from account_migration import migrate_accounts
from structure_migration import migrate_strucutres
from job_migration import migrate_jobs, migrate_job_memos
#from activity_migration import migrate_activities
#from invoice_request_migration import migrate_invoice_requests
from transaction_migration import migrate_transactions

print ("Starting migration.")

get_legacy_system_id()
# Accounts
migrate_accounts()

# Structures
migrate_strucutres()

# Jobs
migrate_jobs(False)

# Activities
#migrate_activities()

# Job Memos
migrate_job_memos()

# Invoice Requests
#migrate_invoice_requests()

# Transactions
migrate_transactions()

# Commit the changes 
dest_conn.commit()
dest_conn.close()

print("Migration complete.")
