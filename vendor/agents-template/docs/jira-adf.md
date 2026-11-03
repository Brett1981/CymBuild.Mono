# Jira (Cloud) and ADF

## The problem

Our Jira is **Cloud**, which stores descriptions and comments as
**ADF — Atlassian Document Format JSON**, not wiki markup.

Passing `h2.`, `||header||`, `{{code}}` or `{panel}` to `acli` does not error. It
stores them as **literal text in one flat paragraph**, and the ticket looks broken
to everyone who opens it. This is the single most common way an agent-written
ticket goes wrong.

## The fix

Write an ADF document to a file and pass `--description-file`. It works on both
create and edit (`edit` also needs `--yes`):

```bash
acli jira workitem create --project <JIRA-PROJECT> --type Task \
  --summary "..." --description-file /tmp/desc.json

acli jira workitem edit <JIRA-PROJECT>-123 --description-file /tmp/desc.json --yes
```

Minimal document:

```json
{"version":1,"type":"doc","content":[
  {"type":"heading","attrs":{"level":2},"content":[{"type":"text","text":"Problem"}]},
  {"type":"paragraph","content":[{"type":"text","text":"Plain, then "},
                                 {"type":"text","text":"bold","marks":[{"type":"strong"}]}]}]}
```

## Node reference

| Node | Notes |
|---|---|
| `heading` | `attrs.level` 1–6 |
| `paragraph` | the workhorse; most nodes wrap one |
| `bulletList` / `orderedList` | → `listItem` → `paragraph` |
| `table` | → `tableRow` → `tableHeader` / `tableCell`, each wrapping a `paragraph` |
| `panel` | `attrs.panelType`: `info`, `note`, `warning`, `success`, `error` |
| `codeBlock` | `attrs.language` |
| `rule` | horizontal divider |

Marks on a `text` node: `strong`, `em`, `code`, `strike`, `link` (`attrs.href`).

## Build it with a script

ADF is too verbose to write reliably by hand. Use the builder at
[../scripts/adf.py](../scripts/adf.py) — `heading`, `para`, `bullets`, `table`,
`panel`, `rule`, `doc`, `write`. Pass `("text", "strong")` tuples for marks:

```python
import sys; sys.path.insert(0, "scripts")
from adf import doc, heading, para, bullets, table, panel, write

write("/tmp/desc.json", doc(
    heading("Problem"),
    para("The deploy job fails with ", ("insufficient_scope", "code"), "."),
    heading("Acceptance criteria"),
    bullets([["Pull secret is built by the deploy job"],
             ["Rebuilt namespaces self-heal"]]),
    panel("warning", "Deploy tokens are scoped to the issuing project."),
))
```

## Always verify

After creating or editing, confirm it stored as *structure* rather than text:

```bash
acli jira workitem view <KEY> --json \
  | python3 -c "import json,sys; print([n['type'] for n in json.load(sys.stdin)['fields']['description']['content']])"
```

Expect a list like `['heading', 'paragraph', 'bulletList', ...]`. If a
multi-section description prints only `['paragraph']`, the markup was stored
literally — rebuild it as ADF.
