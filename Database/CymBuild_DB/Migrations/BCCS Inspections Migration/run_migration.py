from common import *
from account_migration import migrate_accounts
from structure_migration import migrate_strucutres
from job_migration import migrate_jobs, migrate_job_memos, create_empty_jobs
from activity_migration import migrate_activities
from invoice_request_migration import migrate_invoice_requests
from transaction_migration import migrate_transactions, migrate_finance_memos
from quotes_migration import migrate_quotes

print ("Starting migration.")

get_legacy_system_id()

# Accounts
migrate_accounts()

# Structures
migrate_strucutres()

# Jobs
migrate_jobs()

# Activities
migrate_activities()

# Job Memos
migrate_job_memos()

# Invoice Requests
migrate_invoice_requests()

# Transactions
migrate_transactions()

# Finance Memos 
migrate_finance_memos()

# Quotes
migrate_quotes()

# Create the empty jobs 
#create_empty_jobs(10, "BCCS (HRB)")

# Commit the changes 
dest_conn.commit()
dest_conn.close()

print("Migration complete.")
