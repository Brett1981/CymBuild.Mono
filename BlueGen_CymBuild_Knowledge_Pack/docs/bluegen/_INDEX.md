# BlueGen CymBuild Knowledge Pack

This folder is an initial knowledge pack for BlueGen, the CymBuild AI assistant for developers and users.

It is designed to be reviewed and corrected by the CymBuild team before becoming authoritative. The pack combines current CymBuild platform rules, repository inspection from the supplied `CymBuild-Telerik.zip` snapshot, and known implementation patterns.

## Recommended ingestion priority

1. `00_BLUEGEN_SYSTEM_RULES.md`
2. `01_CYMBUILD_ARCHITECTURE.md`
3. `02_NAVIGATION_SCHEMA.yaml`
4. `04_METADATA_RULES.md`
5. `05_GOLDEN_PATH_EXAMPLES.md`
6. `06_TROUBLESHOOTING_PLAYBOOKS.md`
7. `09_GLOSSARY.md`
8. `14_API_GRPC_CONTRACT_MAP.md`

## Files

| File | Purpose |
|---|---|
| `00_BLUEGEN_SYSTEM_RULES.md` | Highest-priority CymBuild behaviour rules for BlueGen. |
| `01_CYMBUILD_ARCHITECTURE.md` | High-level platform guide. |
| `02_NAVIGATION_SCHEMA.yaml` | Repository navigation hints. |
| `03_REPOSITORY_INVENTORY.md` | Actual paths/features found in the uploaded project snapshot. |
| `04_METADATA_RULES.md` | Metadata CI/CD and manifest guidance. |
| `05_GOLDEN_PATH_EXAMPLES.md` | Worked patterns for common changes. |
| `06_TROUBLESHOOTING_PLAYBOOKS.md` | Diagnostic playbooks for support and developers. |
| `07_JIRA_IMPLEMENTATION_HISTORY.md` | Known Jira implementation memory. |
| `08_USER_HELP_GUIDES.md` | User-facing help guide templates/content. |
| `09_GLOSSARY.md` | CymBuild terminology. |
| `10_DEPLOYMENT_RUNBOOKS.md` | DEV/QA/UAT/LIVE deployment guidance. |
| `11_TESTING_AND_DIAGNOSTICS.md` | Safe diagnostic SQL and validation guidance. |
| `12_TELERIK_REMOVAL_GUIDE.md` | Non-Telerik conversion guide. |
| `13_INTEGRATION_GUIDE.md` | Sage, Outlook, SharePoint, outbox, idempotency. |
| `14_API_GRPC_CONTRACT_MAP.md` | FormHelper/API/proto/service map. |
| `15_BLUEGEN_INGESTION_GUIDE.md` | Suggested RAG/assistant ingestion and retrieval design. |

## Important note

This pack should not override source code or source-controlled SQL. If there is a conflict, inspect the repository and schema first.
