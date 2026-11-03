# CymBuild agent instructions and test-generation blueprint

This bundle is the CymBuild equivalent of the supplied SOCOTEC UK agent
template. It is intended to live at the root of `CymBuild.Monorepo` and guide
AI coding agents used from VS Code, Codex, Claude Code, Cursor, Copilot, or a
similar repository-aware tool.

The important difference is that CymBuild cannot use a generic rule such as
"add tests for the page you changed". Much of the PWA is rendered from metadata,
so the proposed model has two complementary test sources:

1. Normal code tests for renderers, FormHelper, gRPC services, EF/repositories,
   SQL contracts, shared components, and architecture boundaries.
2. Deterministic test-case manifests generated from source-controlled metadata
   and the code change impact, then reviewed and committed before CI executes
   them.

No AI agent is added to the running application. Generated tests are not
invented during a deployment and the generator never learns from or writes to
LIVE. The repository and CI/CD pipeline remain the control plane.

## Contents

```text
AGENTS.md
ANALYSIS.md
docs/
  architecture-and-data-rules.md
  testing-strategy.md
  test-case-generation.md
  metadata-driven-ui-testing.md
  ci-cd-and-environments.md
  review-and-delivery.md
  adoption-plan.md
  open-decisions.md
test-cases/
  README.md
  schema/cymbuild-test-case.schema.json
  examples/metadata-form-render.example.json
```

`AGENTS.md` is intentionally short. Detailed rules live in the linked documents
so agents are more likely to read and apply them.

## Recommended adoption

Do not copy this bundle blindly into a release branch. First run the repository
inventory in `docs/adoption-plan.md` against the current CymBuild 26.3 source.
That confirms the real target frameworks, metadata manifest format, existing
test helpers, Bitbucket Pipeline definitions, authentication approach, and
renderer selector support.

The safe first production-repository change is documentation plus the test-case
JSON Schema. Executable generator, scaffold, and browser-test changes should be
added only after that inventory and should be introduced through a normal
reviewed pull request.

## Design outcome

This approach gives CymBuild an agent that can:

- identify which test layers a change affects;
- propose traceable test cases from Jira intent, code, SQL, gRPC contracts, and
  metadata manifests;
- detect when a metadata change has no corresponding contract test;
- generate stable test skeletons without relying on page text or DOM position;
- enforce architecture, DataObject, workflow-transition, SQL, outbox, and
  environment-safety rules;
- run fast tests before integration tests and controlled deployed-environment
  smoke tests;
- explain uncovered risk rather than silently claiming a change is tested.

It cannot safely generate final executable CymBuild tests from this bundle
alone. The current repository is required to map the blueprint to the actual
manifest properties, renderers, helpers, test frameworks, and CI commands.
