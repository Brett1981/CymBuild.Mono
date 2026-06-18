# Cross-server metadata deployment notes

SQL Server three-part names cannot read another SQL Server instance without a linked server.

The SQL-only CI scripts intentionally do not create linked servers. Creating linked servers is a server-level administrative action and should not be part of an application deployment pack.

Supported options:

1. Same SQL Server:
   - Use the full SQL pipeline.
   - `SMigration.MetadataStage_Run` can read `[SourceDatabase].[schema].[table]`.

2. Different SQL Servers without linked server:
   - Use CymBuild API/UI two-connection staging.
   - Apply exact approved RunGuid through CI using `20_metadata_apply_existing_validated_run.sql`.

3. Different SQL Servers with approved linked server:
   - This pack does not create the linked server.
   - If the DBA provides a stable linked-server abstraction, staging SQL can be extended separately.
