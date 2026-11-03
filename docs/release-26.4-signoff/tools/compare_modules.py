"""Compare repo programmable objects (release/26.4 working tree) with CymBuild_Dev module definitions.

Usage: python compare_modules.py <repo root> <dev_modules.json> <out dir>
Writes report.json and prints a summary. Read-only.
"""
import hashlib
import json
import os
import re
import subprocess
import sys

repo, dev_json, out_dir = sys.argv[1:4]
schema_root = os.path.join(repo, "Database", "CymBuild_DB", "Schema")

CREATE_RE = re.compile(
    r"(?im)^[ \t]*CREATE\s+(?:OR\s+ALTER\s+)?(PROCEDURE|PROC|FUNCTION|VIEW|TRIGGER)\s+"
    r"(?:\[?(?P<schema>[A-Za-z0-9_]+)\]?\.)?\[?(?P<name>[A-Za-z0-9_]+)\]?")
KIND = {"PROCEDURE": "P", "PROC": "P", "FUNCTION": "F", "VIEW": "V", "TRIGGER": "TR"}


def strip_comments(sql):
    out, i, n = [], 0, len(sql)
    while i < n:
        if sql.startswith("--", i):
            j = sql.find("\n", i)
            i = n if j < 0 else j
        elif sql.startswith("/*", i):
            depth, i = 1, i + 2
            while i < n and depth:
                if sql.startswith("/*", i):
                    depth, i = depth + 1, i + 2
                elif sql.startswith("*/", i):
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
        elif sql[i] == "'":
            j = i + 1
            while j < n:
                if sql[j] == "'" and j + 1 < n and sql[j + 1] == "'":
                    j += 2
                elif sql[j] == "'":
                    break
                else:
                    j += 1
            out.append(sql[i:j + 1])
            i = j + 1
        else:
            out.append(sql[i])
            i += 1
    return "".join(out)


def norm(body):
    """Body from just after the object name; comments, SCHEMABINDING and whitespace/case ignored."""
    b = strip_comments(body)
    b = re.sub(r"(?i)\bWITH\s+SCHEMABINDING\b", " ", b)
    b = re.sub(r"(?i),\s*SCHEMABINDING\b", " ", b)
    b = re.sub(r"(?im)^\s*GO\s*$", " ", b)
    b = b.replace("[", "").replace("]", "")
    b = re.sub(r"\s+", " ", b).strip().rstrip(";").strip().lower()
    # Generated RecordHistory audit triggers: one independent block per column, order is not significant.
    tail_m = re.search(r"(\s+end)+\s*$", b)
    tail = tail_m.group(0).split() if tail_m else []
    if tail_m:
        b = b[:tail_m.start()]
    # The trailing literal is the per-environment SCore.EntityProperties ID; it legitimately differs.
    b = re.sub(r"(system_user, )-?\d+(\))", r"#", b)
    parts = re.split(r"(?=select @previousvalue = )", b)
    if len(parts) > 2:
        head, blocks = parts[0], parts[1:]
        b = head + " || " + " || ".join(sorted(re.sub(r"(\s+end)+$", "", x.strip()) for x in blocks))
    return b + (" " + " ".join(tail) if tail else "")


def body_after_name(text, m):
    return text[m.end():]


def split_batches(text):
    return re.split(r"(?im)^[ \t]*GO[ \t]*;?[ \t]*$", text)


def objects_in_text(text):
    found = []
    for batch in split_batches(text):
        m = CREATE_RE.search(batch)
        if not m:
            continue
        # a CREATE inside a PRINT/string is excluded by the ^ anchor; take the first real CREATE per batch
        kind = KIND[m.group(1).upper()]
        schema = m.group("schema") or "dbo"
        found.append((kind, f"{schema}.{m.group('name')}".lower(), body_after_name(batch, m)))
    return found


def read(path):
    with open(path, "rb") as f:
        return f.read().decode("utf-8-sig", errors="replace").replace("\r\n", "\n")


repo_objs = {}
folders = [("Programmability/Procedures", False), ("Programmability/Functions", False),
           ("Programmability/Triggers", False), ("Views", False), ("Tables", True)]
for rel, triggers_only in folders:
    d = os.path.join(schema_root, *rel.split("/"))
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".sql") or fn.endswith(".preflight.sql"):
            continue
        p = os.path.join(d, fn)
        for kind, key, body in objects_in_text(read(p)):
            if triggers_only and kind != "TR":
                continue
            repo_objs[key] = {"kind": kind, "path": os.path.relpath(p, repo).replace("\\", "/"), "body": body}

dev = {}
for r in json.load(open(dev_json, encoding="utf-8-sig")):
    t = r["type"]
    kind = {"P": "P", "FN": "F", "IF": "F", "TF": "F", "V": "V", "TR": "TR"}.get(t)
    if not kind:
        continue
    key = f"{r['schema']}.{r['name']}".lower()
    m = CREATE_RE.search(r["definition"] or "")
    body = r["definition"][m.end():] if m else (r["definition"] or "")
    dev[key] = {"kind": kind, "body": body, "modified": r["modified"], "disabled": r.get("disabled")}

cache = {}


def history_match(path, dev_norm, limit=80):
    """Return (commit, date, subject, is_tip) of the newest historic version equal to DEV, else None."""
    if path not in cache:
        revs = subprocess.run(["git", "-C", repo, "log", "--all", f"-n{limit}", "--format=%H|%cs|%s", "--", path],
                              capture_output=True, text=True, encoding="utf-8").stdout.splitlines()
        versions = []
        for line in revs:
            h, date, subj = line.split("|", 2)
            blob = subprocess.run(["git", "-C", repo, "show", f"{h}:{path}"], capture_output=True)
            if blob.returncode:
                continue
            txt = blob.stdout.decode("utf-8-sig", errors="replace").replace("\r\n", "\n")
            key = os.path.basename(path)
            for kind, k, body in objects_in_text(txt):
                versions.append((h[:8], date, subj[:70], k, hashlib.sha1(norm(body).encode()).hexdigest()))
        cache[path] = versions
    target = hashlib.sha1(dev_norm.encode()).hexdigest()
    for h, date, subj, k, hh in cache[path]:
        if hh == target:
            return {"commit": h, "date": date, "subject": subj}
    return None


report = {"missing_in_dev": [], "dev_behind": [], "dev_divergent": [], "extra_in_dev": [], "match": 0}
for key, o in sorted(repo_objs.items()):
    d = dev.get(key)
    if not d:
        report["missing_in_dev"].append({"object": key, "kind": o["kind"], "path": o["path"]})
        continue
    rn, dn = norm(o["body"]), norm(d["body"])
    if rn == dn:
        report["match"] += 1
        continue
    hm = history_match(o["path"], dn)
    entry = {"object": key, "kind": o["kind"], "path": o["path"], "dev_modified": d["modified"]}
    if hm:
        entry["dev_equals"] = hm
        report["dev_behind"].append(entry)
    else:
        i = next((k for k in range(min(len(rn), len(dn))) if rn[k] != dn[k]), min(len(rn), len(dn)))
        entry["repo_snippet"] = rn[max(0, i - 80):i + 160]
        entry["dev_snippet"] = dn[max(0, i - 80):i + 160]
        report["dev_divergent"].append(entry)
for key, d in sorted(dev.items()):
    if key not in repo_objs:
        report["extra_in_dev"].append({"object": key, "kind": d["kind"], "dev_modified": d["modified"]})

json.dump(report, open(os.path.join(out_dir, "report.json"), "w", encoding="utf-8"), indent=1)
print(f"repo objects: {len(repo_objs)}  dev modules: {len(dev)}  identical: {report['match']}")
for k in ("missing_in_dev", "dev_behind", "dev_divergent", "extra_in_dev"):
    print(f"{k}: {len(report[k])}")
