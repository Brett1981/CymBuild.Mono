#!/usr/bin/env python3
"""Format checks for the agents-template docs.

Run locally with `python3 ci/check-docs.py` from the repo root. Exits non-zero
on the first category that fails, printing every offender.

The em-dash check enforces the rule in docs/writing-style.md against this repo's
own prose, so the template practises what it documents.
"""
import glob
import pathlib
import re
import sys

FAILURES = []


def report(category, offenders):
    if offenders:
        FAILURES.append(category)
        print(f"\nFAIL  {category}")
        for o in offenders:
            print(f"  {o}")
    else:
        print(f"ok    {category}")


def md_files():
    return sorted(glob.glob("*.md") + glob.glob("docs/*.md") + glob.glob("ci/*.md"))


def check_links():
    """Every relative markdown link must resolve."""
    bad = []
    for f in md_files():
        base = pathlib.Path(f).parent
        for target in re.findall(r"\]\(([^)]+)\)", pathlib.Path(f).read_text()):
            if target.startswith(("http://", "https://", "#")):
                continue
            if not (base / target.split("#")[0]).exists():
                bad.append(f"{f}: dead link -> {target}")
    report("relative links resolve", bad)


def prose_units(text):
    """Split into the units the em-dash rule applies to.

    Fenced code, inline code and quoted examples are exempt per the protected
    list in docs/writing-style.md. List items and table rows count individually,
    so a run of bullets with one em-dash each is not a violation.
    """
    text = re.sub(r"```.*?```", "", text, flags=re.S)
    text = re.sub(r"`[^`]*`", "", text)
    text = re.sub(r"\"[^\"]*\"", "", text)          # quoted examples of a tell
    text = re.sub(r"^\*\*.+\*\* — see .*$", "", text, flags=re.M)  # pointer construct

    units, buf = [], []
    for line in text.split("\n"):
        is_item = re.match(r"^\s*([-*+]|\d+\.)\s", line) or line.lstrip().startswith("|")
        if is_item:
            if buf:
                units.append("\n".join(buf)); buf = []
            units.append(line)
        elif not line.strip():
            if buf:
                units.append("\n".join(buf)); buf = []
        else:
            buf.append(line)
    if buf:
        units.append("\n".join(buf))
    return [u for u in units if u.strip()]


def check_em_dashes():
    """Two or more em-dashes in one prose unit is a hard flag."""
    bad = []
    for f in md_files():
        for u in prose_units(pathlib.Path(f).read_text()):
            if u.count("—") >= 2:
                bad.append(f"{f}: {u.strip()[:80]}")
    report("em-dash rule (max 1 per prose unit)", bad)


def check_whitespace():
    bad = []
    for f in md_files() + sorted(glob.glob("scripts/*.py") + glob.glob("ci/*.py")):
        text = pathlib.Path(f).read_text()
        for n, line in enumerate(text.split("\n"), 1):
            if line != line.rstrip():
                bad.append(f"{f}:{n}: trailing whitespace")
        if text and not text.endswith("\n"):
            bad.append(f"{f}: no trailing newline")
    report("no trailing whitespace, files end in newline", bad)


def check_adf():
    """The ADF builder must import and produce the structure jira-adf.md claims."""
    bad = []
    sys.path.insert(0, "scripts")
    try:
        from adf import bullets, doc, heading, panel, para
        d = doc(
            heading("Problem"),
            para("Fails with ", ("insufficient_scope", "code"), "."),
            bullets([["one"], ["two"]]),
            panel("warning", "careful"),
        )
        got = [n["type"] for n in d["content"]]
        want = ["heading", "paragraph", "bulletList", "panel"]
        if got != want:
            bad.append(f"scripts/adf.py: produced {got}, expected {want}")
    except Exception as exc:                        # noqa: BLE001
        bad.append(f"scripts/adf.py: {type(exc).__name__}: {exc}")
    report("adf.py builds the documented structure", bad)


if __name__ == "__main__":
    check_links()
    check_em_dashes()
    check_whitespace()
    check_adf()
    if FAILURES:
        print(f"\n{len(FAILURES)} check(s) failed: {', '.join(FAILURES)}")
        sys.exit(1)
    print("\nAll checks passed.")
