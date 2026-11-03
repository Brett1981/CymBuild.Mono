# Evidence required before executable integration

These are not design choices for an agent to guess. Resolve them from the current
repository and deployment owners during Phase 0.

| Evidence needed | Why it matters | Safe default until confirmed |
|---|---|---|
| Exact CymBuild 26.3 base branch/commit for this work | Prevents designing against an obsolete snapshot or release. | Do not edit the production repo. |
| Current Bitbucket branch, commit-signing, issue-key, PR template, and approval rules | The supplied template is GitLab-specific and CymBuild history contains several branch patterns. | Follow an explicitly requested branch only; do not push. |
| Actual metadata manifest locations and schema | Required to generate definition tests without querying a database or inventing properties. | Keep the JSON case schema generic; no executable metadata compiler. |
| Whether all production metadata is represented by manifests today | Determines coverage gaps and migration prerequisites. | Report missing source representation; never promote DB contents manually. |
| Stable metadata Guid/key fields and dependency rules | Required for selectors, de-duplication, and Grid → View → Columns validation. | Do not use numeric database IDs. |
| Current renderer component APIs and fixture patterns | Required to build valid bUnit/component tests. | Do not create speculative model/builders. |
| Current FormHelper boundaries and any approved exceptions | Required for architecture gates without false positives. | Treat UI direct API use as prohibited; inspect before changing legacy code. |
| Current SQL integration harness and disposable database strategy | Required for repeatable DataObject/transition/schema tests. | No remote database mutations. |
| Browser/E2E framework, if any | Avoids adding a second toolchain or conflicting conventions. | Design cases only; no new framework. |
| Stable accessibility/test attributes already exposed | Determines whether `data-cyb-*` attributes are needed. | Prefer existing semantic locators after inspection. |
| QA/UAT authentication and test-user provisioning | Required for reliable permission/journey tests. | Do not automate credentials or real users. |
| QA/UAT test-data isolation and cleanup contract | Prevents collisions and destructive cleanup. | Use disposable/local tests only. |
| Approved LIVE smoke routes and queries | Needed to guarantee non-mutating checks. | No LIVE execution. |
| Current Bitbucket Pipeline stages, runners, image build commands, and reports | Required for correct placement and runtime budgeting of new gates. | Provide documentation only. |
| Final schema/metadata/application deployment ordering and compatibility policy | Existing behaviour must be preserved until deliberately changed. | Do not alter deployment pipeline from this template alone. |
| Current active integration/worker matrix | Prevents testing or deploying retired services. | Treat Sage Wrapper as active and legacy Sage microservice as retained only. |

## Suggested inventory output

Record each answer with:

- decision/evidence;
- exact repository file/type/command or owner-approved policy;
- last verified commit/date;
- impact on this bundle;
- required change, if any;
- unresolved risk.

Once this table is complete, replace proposals and cautious wording in the
repository copy of these documents with exact CymBuild commands and paths. Keep
only facts that the team intends agents to follow.
