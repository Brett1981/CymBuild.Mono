# How we connect to Bluegen (current method)

1. Authenticate once to get a token.
2. Cache that token in memory.
3. Send it as a `Bearer` header on every request after that.

The bit that's probably changed is step 1 — see below.

## Config

Three settings, normally pulled from env vars:

| Env var             | What it is                          | Default                            |
| ------------------- | ----------------------------------- | ---------------------------------- |
| `BLUEGEN_EMAIL`     | account email                       | (required)                         |
| `BLUEGEN_PASSWORD`  | account password                    | (required)                         |
| `BLUEGEN_BASE_URL`  | API base URL                        | `https://bluegen-dev.socotec.com`  |

Timeouts we use: auth = 30s, chat = 50s.

## 1. Get the token  ← the important bit

`POST` to `/api/token` with the **email and password as URL query-string params** (there is **no request body**). The token comes back as `access_token` in the JSON.

**Request**
```
POST https://bluegen-dev.socotec.com/api/token?email=<EMAIL>&password=<PASSWORD>
```
(no body, no headers required)

**Response**
```json
{ "access_token": "..." }
```

We cache that token and reuse it. There's no refresh logic — if it expires you just clear it and call `/api/token` again.

### As pseudocode
```
function get_token():
    if cached_token: return cached_token
    resp = HTTP POST  base_url + "/api/token?email=" + email + "&password=" + password
    if not resp.ok: error("Authentication failed")
    cached_token = resp.json["access_token"]
    return cached_token
```


## 2. Send a chat request

`POST /api/chat` with the token as a Bearer header. The answer is in `ai_response`.

**Request**
```
POST /api/chat
Headers:
  Content-Type: application/json
  Authorization: Bearer <token>
Body:
  { "message": "<your prompt>" }        // optionally also "folder": "<folder>" (see uploads)
```

**Response**
```json
{ "ai_response": "...the model's text..." }
```

If you asked for JSON back, the text in `ai_response` contains it — we just grab everything
from the first `{` to the last `}` and parse it.

### As pseudocode
```
function chat(message, folder=None):
    token = get_token()
    body = { "message": message }
    if folder: body["folder"] = folder
    resp = HTTP POST base_url + "/api/chat"
              headers = { "Content-Type": "application/json",
                          "Authorization": "Bearer " + token }
              body    = json(body)
    if not resp.ok: error("Chat request failed")
    return resp.json["ai_response"]
```

## 3. (Optional) Attach a file — PDF/image/DOCX

Two-step upload to S3 via a presigned URL, then reference the returned `folder` in your chat
call.

**Step A — get a presigned URL** (Bearer auth)
```
POST /api/generate-presigned-url
Headers: Content-Type: application/json,  Authorization: Bearer <token>
Body:    { "files": ["<filename>"] }
Response:{ "presigned_url": ["<s3-url>"], "folder": "<folder-ref>" }
```

**Step B — upload the bytes straight to S3** (no Bearer, just the file)
```
PUT <s3-url>
Headers: Content-Type: <file mime type>
Body:    <raw file bytes>
```

Then call `/api/chat` with `"folder": "<folder-ref>"` and the model can see the file.

## Endpoint summary

| Endpoint                       | Method | Auth          | Purpose                          |
| ------------------------------ | ------ | ------------- | -------------------------------- |
| `/api/token`                   | POST   | none (creds in query) | get access token         |
| `/api/chat`                    | POST   | Bearer token  | send prompt, get `ai_response`   |
| `/api/generate-presigned-url`  | POST   | Bearer token  | get S3 upload URL + folder ref   |
| `<presigned s3 url>`           | PUT    | none          | upload the file bytes            |

## TL;DR for the comparison

- Auth = `POST /api/token?email=...&password=...` with **creds in the query string, no body**;
  read `access_token` off the response.
- Cache the token, reuse it as `Authorization: Bearer <token>` on everything else.
- Chat = `POST /api/chat` with `{ "message": ... }`, answer is `ai_response`.
