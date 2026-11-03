"""Update R4-Sql-Test-Schema.json sha256 entries for the given schema-relative paths.

Usage: python r4hash.py <repo root> <Schema-relative path> [...]
Hash = SHA-256 of UTF-8 text with BOM stripped and CRLF/CR normalised to LF
(mirrors Get-NormalizedTextHash in tools/Testing/Initialize-CymBuildSqlTestDatabase.ps1).
"""
import hashlib
import os
import re
import sys

root = sys.argv[1]
manifest = os.path.join(root, "tools", "Testing", "R4-Sql-Test-Schema.json")
text = open(manifest, "rb").read().decode("utf-8")
for rel in sys.argv[2:]:
    b = open(os.path.join(root, "Database", "CymBuild_DB", "Schema", rel), "rb").read()
    if b.startswith(b"\xef\xbb\xbf"):
        b = b[3:]
    h = hashlib.sha256(b.decode("utf-8").replace("\r\n", "\n").replace("\r", "\n").encode("utf-8")).hexdigest().upper()
    pat = re.compile(r'("path":\s*"' + re.escape(rel) + r'",\s*"sha256":\s*")([0-9A-F]{64})(")')
    m = pat.search(text)
    if not m:
        print(f"NOT IN MANIFEST: {rel}")
        continue
    print(f"{rel}: {m.group(2)} -> {h}")
    text = pat.sub(lambda mm: mm.group(1) + h + mm.group(3), text, count=1)
open(manifest, "wb").write(text.encode("utf-8"))
