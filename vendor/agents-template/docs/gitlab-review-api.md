# GitLab review API via `glab`

Hard-won mechanics for posting and resolving MR review threads from the command
line. These are the things that fail silently or with unhelpful errors.

## The 415 trap

`glab api` does **not** set a JSON content type for you. Without an explicit
header, GitLab returns `HTTP 415 Unsupported Media Type`:

```bash
glab api --method POST -H "Content-Type: application/json" \
  "projects/<url-encoded-path>/merge_requests/<IID>/discussions" --input -
```

`<url-encoded-path>` is the full project path with `/` as `%2F`, e.g.
`socotec-group%2Fuk%2Finfra%2Fmyapp`.

## Anchoring a comment to a diff line

You need the `diff_refs` SHAs from the MR itself:

```bash
glab api "projects/<url-encoded-path>/merge_requests/<IID>" \
  | python3 -c "import json,sys; print(json.load(sys.stdin)['diff_refs'])"
```

Then the payload:

```json
{"body": "**High:** ...markdown...",
 "position": {"position_type": "text",
              "base_sha": "...", "start_sha": "...", "head_sha": "...",
              "new_path": "src/...", "old_path": "src/...", "new_line": 42}}
```

- For **added** lines set `new_line` only — do not also send `old_line`.
- Set `old_path` equal to `new_path`, **even for new files**.
- Omit `position` entirely for a top-level MR note.
- **Build the payload with a small Python script**, not shell heredocs — markdown
  bodies contain backticks, quotes and newlines that shell-escaping mangles.
- Verify the anchors actually landed:

  ```bash
  glab api "projects/<url-encoded-path>/merge_requests/<IID>/discussions?per_page=50"
  ```

  A thread that failed to anchor comes back as a plain note with no `position`.

## Resolving a thread

Same explicit content type. `{"resolved": false}` unresolves.

```bash
echo '{"resolved": true}' | glab api --method PUT -H "Content-Type: application/json" \
  "projects/<url-encoded-path>/merge_requests/<IID>/discussions/<DISCUSSION_ID>" --input -
```

### Check `resolvable` and `resolved` first

Only **diff notes** can be resolved. System notes ("added 1 commit", "changed the
description") and plain MR comments come back `resolvable: false`, and the call
fails on them. Both fields are listed per note in the discussions response:

```bash
glab api "projects/<url-encoded-path>/merge_requests/<IID>/discussions?per_page=50" \
  | python3 -c "
import json,sys
for d in json.load(sys.stdin):
    n = d['notes'][0]
    print(d['id'][:8], n.get('resolvable'), n.get('resolved'), n['body'][:60].replace(chr(10),' '))
"
```

A thread may **already** be resolved — someone did it in the UI, or GitLab did it
automatically because the line went outdated and the project has
`resolve_outdated_diff_discussions` enabled. That setting is **off by default**;
check it per project rather than assuming either way.

## Permission notes

Some agent sandboxes block decoding secret *values* (e.g. base64 of a
`.dockerconfigjson`) and certain `deploy_tokens` listings. Comparing a SHA-256
fingerprint of a credential across namespaces is usually enough to spot a copied
token without ever printing it.
