#!/usr/bin/env bash
#
# worktree/setup.sh — isolated git worktree + temp Postgres DB for a ticket.
#
# For the SOCOTEC "Hub" apps: Next.js + Prisma 7 on the shared local Postgres
# (clienthub, projecthub, form-generator, tender-intelligence, …). It:
#   - creates a git worktree under  <repo>/.claude/worktrees/<slug>
#   - on a branch  <branch-prefix>/<slug>  (override --branch) cut from origin/main (--base)
#   - symlinks .env / .env.local / node_modules from the main checkout
#   - creates a temp DB  <dbname>_<slug>  cloned from the current DB (schema + data)
#   - runs `prisma generate` IN the worktree (Prisma 7 writes a gitignored client)
#   - writes  <worktree>/worktree.env  exporting the temp DATABASE_URL
#
# Two things that make these apps different from a generic Next repo, and which the
# earlier version of this skill got wrong:
#
#   1. Prisma 7's `prisma-client` generator outputs to a REPO-LOCAL, GITIGNORED path
#      (e.g. src/generated/prisma). A fresh worktree does not have it and symlinking
#      node_modules does NOT help — the client no longer lives there. Without a
#      `prisma generate` the app dies on boot with "Cannot find module
#      '@/generated/prisma/client'". So we always generate in the worktree.
#
#   2. SSO (Azure AD) redirect URIs are pinned to each app's CANONICAL port
#      (clienthub 3002, projecthub 3007, form-generator 3003 …). You cannot move the
#      dev server to a "free" port and still log in. So this script does NOT assign a
#      port — it detects the canonical one and warns if it is already in use. Only one
#      interactive instance can hold that port at a time; stop the other first.
#      (Non-interactive work — prisma db push, migrate, seed, tests — needs no port and
#      IS what the per-worktree temp DB is for: run those on many worktrees in parallel.)
#
# The DATABASE_URL override still works the same way: dotenv (Prisma) and @next/env
# (Next) never overwrite a var that is already in the environment, so `source
# worktree.env` points BOTH the app and every `bunx prisma …` at the temp DB even
# though .env is a symlink to the shared one.
#
# Usage:
#   setup.sh <slug> [options]
#     --branch <name>    branch to create/use            (default: <branch-prefix>/<slug>)
#     --base   <ref>     base to cut the branch from      (default: origin/HEAD, else main)
#     --db     <name>    temp database name               (default: <dbname>_<slug>)
#     --from-db <name>   DB to clone as template          (default: the repo's current DB)
#     --empty            create an empty DB + `prisma db push` instead of cloning data
#     --no-db            skip the database entirely (worktree + env only)
#     --no-modules       do NOT symlink node_modules (run `bun install` yourself)
#
set -euo pipefail

# ---- args -------------------------------------------------------------------
SLUG="${1:-}"; shift || true
[ -n "$SLUG" ] || { echo "error: need a <slug> (e.g. ph-63 or sh539)"; exit 2; }
# sanitise slug for a branch/dir/db-identifier: lowercase, non-alnum -> _
SAFE=$(printf '%s' "$SLUG" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g; s/__*/_/g; s/^_//; s/_$//')

BRANCH=""; BASE=""; DBNAME=""; FROMDB=""; EMPTY=0; NODB=0; NOMODULES=0
while [ $# -gt 0 ]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2;;
    --base)   BASE="$2";   shift 2;;
    --db)     DBNAME="$2"; shift 2;;
    --from-db) FROMDB="$2"; shift 2;;
    --empty)  EMPTY=1; shift;;
    --no-db)  NODB=1; shift;;
    --no-modules) NOMODULES=1; shift;;
    *) echo "error: unknown option '$1'"; exit 2;;
  esac
done

# ---- locate repo ------------------------------------------------------------
REPO=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "error: not inside a git repo"; exit 2; }
cd "$REPO"
REPO_NAME=$(basename "$REPO")
# Branch namespace. Adopters: export BRANCH_PREFIX or replace the default here.
# See the <branch-prefix> placeholder in AGENTS.md.
BRANCH_PREFIX="${BRANCH_PREFIX:-$USER}"
[ -n "$BRANCH" ] || BRANCH="$BRANCH_PREFIX/$SAFE"

# base branch: --base, else origin/HEAD, else main
if [ -z "$BASE" ]; then
  BASE=$(git rev-parse --abbrev-ref origin/HEAD 2>/dev/null || true)
  [ -n "$BASE" ] || BASE="main"
fi
git fetch --quiet origin 2>/dev/null || true

WT="$REPO/.claude/worktrees/$SAFE"

# ---- create the worktree ----------------------------------------------------
if git worktree list --porcelain | grep -qxF "worktree $WT"; then
  echo "• worktree already exists: $WT"
else
  mkdir -p "$(dirname "$WT")"
  if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
    echo "• checking out existing branch $BRANCH into worktree"
    git worktree add "$WT" "$BRANCH"
  else
    echo "• creating branch $BRANCH off $BASE"
    git worktree add -b "$BRANCH" "$WT" "$BASE"
  fi
fi

# ---- symlink env + node_modules --------------------------------------------
for f in .env .env.local; do
  if [ -e "$REPO/$f" ] && [ ! -e "$WT/$f" ]; then
    ln -s "$REPO/$f" "$WT/$f"
    echo "• symlinked $f"
  fi
done
if [ "$NOMODULES" -eq 0 ] && [ -d "$REPO/node_modules" ] && [ ! -e "$WT/node_modules" ]; then
  ln -s "$REPO/node_modules" "$WT/node_modules"
  echo "• symlinked node_modules"
fi

# ---- read the source DATABASE_URL ------------------------------------------
# .env.local overrides .env (Next precedence); take the last DATABASE_URL we see.
read_src_url() {
  local url=""
  for f in "$REPO/.env" "$REPO/.env.local"; do
    [ -f "$f" ] || continue
    local v
    v=$(grep -E '^\s*DATABASE_URL=' "$f" | tail -n1 | sed -E 's/^\s*DATABASE_URL=//; s/^"//; s/"$//') || true
    [ -n "$v" ] && url="$v"
  done
  printf '%s' "$url"
}

# ---- detect the canonical (SSO-pinned) dev port -----------------------------
# We do NOT reassign it — SSO redirect URIs are registered for this exact port.
# We just surface it and warn if something already holds it.
detect_canonical_port() {
  local dev port=""
  dev=$(python3 -c "import json;print(json.load(open('package.json'))['scripts'].get('dev',''))" 2>/dev/null || true)
  # `next dev -p 3002`  or  `--port 3002`
  port=$(printf '%s' "$dev" | grep -oE '(-p|--port)[= ]+[0-9]+' | grep -oE '[0-9]+' | head -1 || true)
  # `PORT=3007 node server.js`
  [ -n "$port" ] || port=$(printf '%s' "$dev" | grep -oE 'PORT=[0-9]+' | grep -oE '[0-9]+' | head -1 || true)
  # fallback: BASE_URL / NEXT_PUBLIC_BASE_URL / AAD_REDIRECT_URI in .env
  [ -n "$port" ] || port=$(grep -hoE 'localhost:[0-9]+' "$REPO/.env" 2>/dev/null | grep -oE '[0-9]+' | head -1 || true)
  printf '%s' "$port"
}
port_in_use() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null && { exec 3>&- 2>/dev/null || true; return 0; } || return 1; }

CANON_PORT=$(detect_canonical_port)

# ---- database ---------------------------------------------------------------
TEMP_URL=""
if [ "$NODB" -eq 1 ]; then
  echo "• skipping database (--no-db)"
else
  SRC_URL=$(read_src_url)
  [ -n "$SRC_URL" ] || { echo "error: no DATABASE_URL found in .env/.env.local; use --no-db"; exit 2; }

  # parse postgresql://user:pass@host:port/dbname?params
  proto_stripped=${SRC_URL#*://}
  creds=${proto_stripped%%@*}
  hostpart=${proto_stripped#*@}
  DB_USER=${creds%%:*}
  DB_PASS=${creds#*:}; [ "$DB_PASS" = "$creds" ] && DB_PASS=""
  hostport=${hostpart%%/*}
  DB_HOST=${hostport%%:*}
  DB_PORT=${hostport#*:}; [ "$DB_PORT" = "$hostport" ] && DB_PORT=5432
  rest=${hostpart#*/}
  SRC_DB=${rest%%\?*}
  PARAMS=""; [ "$rest" != "$SRC_DB" ] && PARAMS="?${rest#*\?}"

  [ -n "$DBNAME" ] || DBNAME="${SRC_DB}_${SAFE}"
  [ -n "$FROMDB" ] || FROMDB="$SRC_DB"
  TEMP_URL="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:${DB_PORT}/${DBNAME}${PARAMS}"

  export PGPASSWORD="$DB_PASS"
  PSQL=(psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -d postgres -v ON_ERROR_STOP=1 -tAc)

  exists=$("${PSQL[@]}" "SELECT 1 FROM pg_database WHERE datname='${DBNAME}'" || true)
  if [ "$exists" = "1" ]; then
    echo "• temp DB already exists: $DBNAME (leaving as-is)"
  elif [ "$EMPTY" -eq 1 ]; then
    echo "• creating empty DB $DBNAME + prisma db push"
    createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DBNAME"
    ( cd "$WT" && DATABASE_URL="$TEMP_URL" bunx prisma db push )
  else
    echo "• cloning $FROMDB → $DBNAME (schema + data)"
    # Fast path: server-side template copy. Requires no active connections to FROMDB
    # (i.e. the main dev server / prisma studio must be stopped). Falls back otherwise.
    if createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -T "$FROMDB" "$DBNAME" 2>/dev/null; then
      echo "  (copied via TEMPLATE)"
    else
      echo "  (template busy — falling back to pg_dump | psql; slower)"
      createdb -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" "$DBNAME"
      pg_dump -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" --no-owner --no-privileges "$FROMDB" \
        | psql -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" -q -d "$DBNAME" -v ON_ERROR_STOP=1 >/dev/null
    fi
  fi
fi

# ---- prisma generate (REQUIRED for Prisma 7's repo-local client) ------------
# Always run: the generated client is gitignored and per-worktree. Non-fatal so a
# generate failure (e.g. --no-modules with no install) still leaves a usable DB.
if [ -f "$WT/prisma.config.ts" ] || [ -f "$WT/prisma/schema.prisma" ]; then
  echo "• prisma generate (worktree client)"
  # generate only reads the schema — it needs no DATABASE_URL, so keep this simple.
  if ( cd "$WT" && bunx prisma generate >/dev/null 2>&1 ); then
    echo "  (generated)"
  else
    echo "  ⚠ prisma generate failed — run 'bunx prisma generate' in the worktree yourself"
  fi
fi

# ---- write worktree.env (the DB override layer) -----------------------------
{
  echo "# Generated by worktree/setup.sh — source this before \`bun run dev\` or \`bunx prisma …\`."
  echo "# The exported DATABASE_URL wins over the symlinked .env for BOTH Next and Prisma"
  echo "# (dotenv/@next/env won't overwrite an already-set var), so this worktree stays on"
  echo "# its own DB. Port is NOT overridden — the app must run on its canonical SSO port."
  [ -n "$TEMP_URL" ] && echo "export DATABASE_URL=\"$TEMP_URL\""
} > "$WT/worktree.env"
echo "• wrote worktree.env"

# ---- port warning -----------------------------------------------------------
PORT_NOTE=""
if [ -n "$CANON_PORT" ] && port_in_use "$CANON_PORT"; then
  PORT_NOTE="⚠ port $CANON_PORT is already in use — stop the other instance (main checkout or another
     worktree) before \`bun run dev\` here, or SSO login will hit the wrong process."
fi

# ---- summary ----------------------------------------------------------------
cat <<EOF

✅ Worktree ready for '$SLUG'
   path     : $WT
   branch   : $BRANCH  (base $BASE)
   dev port : ${CANON_PORT:-<app default>}  (SSO-pinned — do not change)
$( [ -n "$TEMP_URL" ] && echo "   database : $DBNAME" || echo "   database : (none)" )
${PORT_NOTE:+
   $PORT_NOTE}

Interactive (needs SSO → the canonical port, one instance at a time):
   cd $WT
   source worktree.env
   bun run dev        # binds the app's canonical port

Non-interactive (no port needed — run these on many worktrees in parallel):
   cd $WT && source worktree.env && bunx prisma studio   # or db push / migrate / seed / tests

Tear down when done:
   git -C "$REPO" worktree remove "$WT"$( [ -n "$TEMP_URL" ] && printf '\n   dropdb -h %s -p %s -U %s %s' "$DB_HOST" "$DB_PORT" "$DB_USER" "$DBNAME" )
EOF
