"""Compare repo tables/columns/indexes/constraints with CymBuild_Dev exports. Read-only.

Usage: python compare_tables.py <repo root> <devsync dir>
"""
import os
import re
import sys

repo, d = sys.argv[1:3]
schema = os.path.join(repo, "Database", "CymBuild_DB", "Schema")


def read(p):
    return open(p, "rb").read().decode("utf-8-sig", errors="replace").replace("\r\n", "\n")


def load(name):
    return set(l.strip() for l in open(os.path.join(d, f"dev_{name}.txt"), encoding="utf-8-sig") if l.strip())


dev_cols, dev_idx, dev_con = load("columns"), load("indexes"), load("constraints")
dev_tables = {x.split("|")[0] for x in dev_cols}

repo_cols, repo_idx, repo_con = set(), set(), set()
for fn in os.listdir(os.path.join(schema, "Tables")):
    if not fn.endswith(".sql") or fn.endswith(".preflight.sql"):
        continue
    t = read(os.path.join(schema, "Tables", fn))
    m = re.search(r"(?is)CREATE\s+TABLE\s+\[?(\w+)\]?\.\[?(\w+)\]?\s*\((.*?)\n\)", t)
    if not m:
        continue
    table = f"{m.group(1)}.{m.group(2)}".lower()
    for line in m.group(3).split("\n"):
        c = re.match(r"\s*\[(\w+)\]\s", line)
        if c:
            repo_cols.add(f"{table}|{c.group(1).lower()}")
        k = re.search(r"CONSTRAINT\s+\[(\w+)\]", line)
        if k:
            repo_con.add(f"{table}|{k.group(1).lower()}")
    for k in re.finditer(r"(?i)ADD\s+CONSTRAINT\s+\[(\w+)\]", t):
        repo_con.add(f"{table}|{k.group(1).lower()}")
    for k in re.finditer(r"(?i)CREATE\s+(?:UNIQUE\s+)?(?:CLUSTERED\s+|NONCLUSTERED\s+)?INDEX\s+\[(\w+)\]\s+ON\s+\[?(\w+)\]?\.\[?(\w+)\]?", t):
        repo_idx.add(f"{k.group(2)}.{k.group(3)}|{k.group(1)}".lower())

for sub, target in (("Indexes", repo_idx), ("Constraints", repo_con)):
    root = os.path.join(schema, sub)
    if not os.path.isdir(root):
        continue
    for dp, _, files in os.walk(root):
        for fn in files:
            if not fn.endswith(".sql") or fn.endswith(".preflight.sql"):
                continue
            t = read(os.path.join(dp, fn))
            for k in re.finditer(r"(?i)CREATE\s+(?:UNIQUE\s+)?(?:CLUSTERED\s+|NONCLUSTERED\s+)?INDEX\s+\[(\w+)\]\s+ON\s+\[?(\w+)\]?\.\[?(\w+)\]?", t):
                repo_idx.add(f"{k.group(2)}.{k.group(3)}|{k.group(1)}".lower())
            for k in re.finditer(r"(?is)ALTER\s+TABLE\s+\[?(\w+)\]?\.\[?(\w+)\]?.*?ADD\s+CONSTRAINT\s+\[(\w+)\]", t):
                repo_con.add(f"{k.group(1)}.{k.group(2)}|{k.group(3)}".lower())

repo_tables = {x.split("|")[0] for x in repo_cols}
print("tables  repo:", len(repo_tables), " dev:", len(dev_tables))
print("MISSING TABLES IN DEV:", sorted(repo_tables - dev_tables) or "none")
mc = sorted(c for c in repo_cols - dev_cols if c.split("|")[0] in dev_tables)
print("MISSING COLUMNS IN DEV:", mc or "none")
mi = sorted(i for i in repo_idx - dev_idx if i.split("|")[0] in dev_tables)
print("MISSING INDEXES IN DEV:", mi or "none")
mk = sorted(k for k in repo_con - dev_con if k.split("|")[0] in dev_tables)
print("MISSING CONSTRAINTS IN DEV:", mk or "none")
print("tables only in DEV:", len(dev_tables - repo_tables), sorted(dev_tables - repo_tables)[:40])
print("columns only in DEV (repo tables):", len([c for c in dev_cols - repo_cols if c.split('|')[0] in repo_tables]))
