"""Compare a DEV object definition dump with a git revision of the repo file (whitespace-insensitive body).

Usage: python driftcheck.py <dev dump file> <git rev:path>
"""
import re
import subprocess
import sys

dev = open(sys.argv[1], encoding="utf-8", errors="replace").read()
base = subprocess.run(["git", "show", sys.argv[2]], capture_output=True, check=True).stdout.decode("utf-8-sig")


def body(t):
    m = re.search(r"(?i)CREATE\s+(OR\s+ALTER\s+)?(PROCEDURE|FUNCTION|VIEW|TRIGGER)", t)
    t = t[m.end():]
    t = re.sub(r"(?im)^\s*GO\s*$", "", t)
    return re.sub(r"\s+", " ", t).strip()


a, b = body(dev), body(base)
print("MATCH" if a == b else "DRIFT")
if a != b:
    i = next((k for k in range(min(len(a), len(b))) if a[k] != b[k]), min(len(a), len(b)))
    print("first diff at", i)
    print("DEV :", a[max(0, i - 120):i + 200])
    print("REPO:", b[max(0, i - 120):i + 200])
