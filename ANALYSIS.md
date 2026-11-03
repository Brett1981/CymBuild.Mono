# Analysis of the supplied agent template for CymBuild

## Executive conclusion

The supplied template is a strong pattern for repository-level agent guidance:
its entry file is short, detail is split into focused documents, and it records
failure modes that are not obvious from source code. CymBuild should adopt that
shape, but not copy its content unchanged.

For CymBuild, the highest-value extension is a deterministic test-impact and
test-case generation model. Dynamic rendering does not prevent automation. It
changes the stable unit under test from "a hand-written page" to three contracts:

1. the generic renderer's behaviour for each supported metadata feature;
2. the validity and semantics of each deployed metadata definition;
3. a small number of end-to-end business journeys proving that rendered
   controls still travel through FormHelper, gRPC, EF, and SQL correctly.

The agent should plan and scaffold those tests, but committed source and
deterministic tooling—not an LLM running in CI or LIVE—must execute and govern
them.

## What the original template does well

| Strength | CymBuild value |
|---|---|
| Small `AGENTS.md` linking to focused documents | Keeps the non-negotiable CymBuild rules visible without creating an unreadable wall of text. |
| Records operational traps rather than restating code | Ideal for DataObjects, transitions, metadata ordering, SQL idempotency, and environment mapping. |
| Requires findings to be verified against real code | Prevents speculative changes to a large legacy codebase. |
| Closes the review-thread loop | Preserves accountability for deferred production risks. |
| Requires tests for changed code | Correct principle, but CymBuild needs a much more precise impact model. |
| Separates Git/CI/Jira details | The same modularity can be retained while replacing GitLab-specific content with Bitbucket/CymBuild rules. |

## What must not be copied unchanged

| Original rule or omission | Why it is unsuitable for CymBuild | Replacement |
|---|---|---|
| GitLab `glab`, GitLab MR endpoints, and GitLab Kubernetes Agent contexts | CymBuild is currently in Bitbucket and uses its own pipeline and RKE2/Rancher deployment route. | Repository-specific Bitbucket review rules and confirmed pipeline commands. |
| Push both SHA and `latest` | Conflicts with build-once/promote-the-same-immutable-artefact governance. | Immutable release identity and digest promotion; no `latest` in controlled environments. |
| Deploy on every push to `main` | Does not express schema-before-metadata ordering or UAT/LIVE approvals. | Explicit validation, preview, approval, apply, verification, application rollout, and smoke gates. |
| Generic "add tests covering changed code" | A metadata change can alter many rendered screens without changing a `.razor` page. | Diff-to-contract impact analysis plus metadata instance test cases. |
| No application architecture rules | An agent could put business logic in Razor or bypass FormHelper. | Mandatory UI → FormHelper → gRPC → EF → SQL boundary tests. |
| No managed-entity/workflow rules | Tests could pass while violating DataObject or transition invariants. | Insert and workflow assertions in integration test policy. |
| No schema/metadata source-of-truth rules | Encourages fixes against a database rather than source. | Source-controlled SQL and manifests; database is a deployment target only. |
| No environment data policy | Browser tests could mutate UAT or LIVE. | Per-environment test modes with LIVE restricted to non-destructive checks. |
| Review explicitly assumes a subagent | Not every agent host provides delegation, and independence matters more than mechanism. | Require an independent review pass when available; otherwise perform and document the same verified checklist. |

## Why dynamic rendering is testable

CymBuild's metadata-driven UI creates two separate risks:

- **renderer regression**: a generic renderer stops honouring a metadata feature;
- **metadata regression**: a particular form/grid definition is invalid,
  duplicated, misordered, inaccessible, or wired to the wrong contract.

Those risks should not be tested by generating thousands of brittle browser
scripts. The efficient model is:

| Level | Purpose | Typical evidence |
|---|---|---|
| Renderer component contracts | Prove each metadata feature once across representative combinations. | Synthetic metadata fixtures, bUnit/component tests, validation and event assertions. |
| Metadata manifest contracts | Prove every definition is structurally valid and references valid dependencies. | Stable Guids, dependency graph, Grid → View → Columns, field/action bindings, duplicate checks. |
| FormHelper/API contracts | Prove a rendered action uses the allowed client/server path. | Mocked gRPC client at FormHelper boundary, API/service tests, protobuf contracts. |
| EF/SQL integration | Prove persistence, DataObjects, transition state, RowStatus and idempotency rules. | Disposable or controlled test database. |
| E2E journeys | Prove a small set of critical journeys after deployment. | Stable metadata-derived selectors and controlled test identities/data. |

This gives broad dynamic coverage without coupling tests to captions, CSS
layout, DOM indexes, or environment-specific database IDs.

## Proposed agent architecture

The agent behaviour is split into five deterministic stages:

1. **Evidence collection** — read the request/Jira item, changed files, linked
   contracts, SQL, manifests, and current tests.
2. **Impact classification** — map each change to architecture, component,
   FormHelper, gRPC, EF/SQL, metadata-contract, integration, or E2E layers.
3. **Candidate case planning** — create stable, reviewable case manifests with
   sources, preconditions, actions, assertions, environments, data policy, and
   automation target.
4. **Scaffolding** — add code only into the real existing test framework after
   the repository inventory confirms its conventions and helpers.
5. **Verification and reporting** — run the relevant suites, compare expected
   coverage, and report anything not executed or not safely automatable.

The proposed JSON Schema in this bundle makes the case-planning output
machine-checkable before a C# generator exists.

## What can enter the CymBuild production repository now

Low-risk first pull request:

- root `AGENTS.md` and linked architecture/testing guidance;
- `test-cases` JSON Schema and one synthetic example;
- an architecture test confirming the guidance and schema stay present, if that
  matches the current architecture-test conventions;
- CI validation that case manifests are valid, after the current toolchain is
  confirmed.

This changes developer and agent behaviour but does not change runtime CymBuild.

## What requires the current CymBuild source before implementation

- mapping actual metadata manifest properties and stable identifiers;
- choosing or extending the existing component-test fixture builders;
- selecting the correct browser/E2E framework already accepted by the repo;
- adding stable selector attributes at the correct generic renderer layer;
- mapping FormHelper methods to generated cases;
- selecting disposable SQL test setup and cleanup mechanisms;
- wiring Bitbucket Pipeline steps and deployment smoke tests;
- confirming authentication and test-user provisioning in QA/UAT;
- determining which LIVE smoke checks are both useful and strictly non-mutating.

Adding executable code before those facts are inspected would violate the
CymBuild rule not to assume missing schema or contracts.

## Recommended decision

Adopt the repository guidance and manifest contract first, then integrate the
executable generator in phases against a fresh CymBuild 26.3 checkout. Do not
place an autonomous test-generating service inside the PWA/API or deploy one to
LIVE. The production-grade outcome is an agent-assisted, source-controlled test
authoring workflow with deterministic CI execution and controlled
post-deployment verification.
