# BlueGen CymBuild Knowledge Pack — Release 26.3

> **Release baseline:** CymBuild 26.3  
> **Validated:** 4 August 2026  
> **Schema deployment baseline:** CYB361_R27 (QA deployment completed with `DeploymentApplied`)  
> **Source basis:** `CymBuild.Monorepo(8).zip`, uploaded schema, and the reviewed CYB361 R22–R27 changes.

This is the reviewed 26.3 knowledge pack, updated from the current source-of-truth repository/schema and the verified CYB361 R27 QA deployment.

## Recommended ingestion priority

1. `00_BLUEGEN_SYSTEM_RULES.md`
2. `16_RELEASE_26_3_BASELINE.md`
3. `01_CYMBUILD_ARCHITECTURE.md`
4. `02_NAVIGATION_SCHEMA.yaml`
5. `04_METADATA_RULES.md`
6. `10_DEPLOYMENT_RUNBOOKS.md`
7. `05_GOLDEN_PATH_EXAMPLES.md`
8. `06_TROUBLESHOOTING_PLAYBOOKS.md`
9. `14_API_GRPC_CONTRACT_MAP.md`

## Files

| File | Purpose |
|---|---|
| `00_BLUEGEN_SYSTEM_RULES.md` | Highest-priority architecture, identity, workflow, SQL and deployment rules. |
| `01_CYMBUILD_ARCHITECTURE.md` | Full platform architecture and standards. |
| `02_NAVIGATION_SCHEMA.yaml` | Valid YAML navigation map for source analysis. |
| `03_REPOSITORY_INVENTORY.md` | Current projects and high-value 26.3 files. |
| `04_METADATA_RULES.md` | Hybrid run-based metadata migration and manifest governance. |
| `05_GOLDEN_PATH_EXAMPLES.md` | Correct implementation paths. |
| `06_TROUBLESHOOTING_PLAYBOOKS.md` | Workflow, metadata, schema, integration and UI diagnosis. |
| `07_JIRA_IMPLEMENTATION_HISTORY.md` | Historical implementation decisions including CYB-361/CYB-362. |
| `08_USER_HELP_GUIDES.md` | Business and admin usage guidance. |
| `09_GLOSSARY.md` | 26.3 terminology. |
| `10_DEPLOYMENT_RUNBOOKS.md` | Controlled R27 schema and metadata deployment guidance. |
| `11_TESTING_AND_DIAGNOSTICS.md` | Source-verified explicit-column diagnostics. |
| `12_TELERIK_REMOVAL_GUIDE.md` | V2/non-Telerik parity guide. |
| `13_INTEGRATION_GUIDE.md` | Outbox, workers, Sage microservice, Outlook and SharePoint. |
| `14_API_GRPC_CONTRACT_MAP.md` | Current FormHelper/proto/service map. |
| `15_BLUEGEN_INGESTION_GUIDE.md` | Authority, routing and RAG metadata. |
| `16_RELEASE_26_3_BASELINE.md` | Verified release state and known caveats. |

This pack does not override current source-controlled code or SQL. Database state is a deployment target/audit source, not the authoring source.
