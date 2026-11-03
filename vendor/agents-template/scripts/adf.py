"""Minimal Atlassian Document Format builder.

Jira Cloud stores descriptions as ADF, not wiki markup — `h2.` and `||th||`
arrive as literal text. acli's --description-file accepts an ADF document, so
build one.
"""
import json


def text(value, *marks):
    node = {"type": "text", "text": value}
    if marks:
        node["marks"] = [{"type": m} for m in marks]
    return node


def rich(*parts):
    """Parts are either plain strings or (string, *marks) tuples."""
    out = []
    for p in parts:
        if isinstance(p, tuple):
            out.append(text(p[0], *p[1:]))
        else:
            out.append(text(p))
    return out


def heading(value, level=2):
    return {"type": "heading", "attrs": {"level": level},
            "content": [text(value)]}


def para(*parts):
    return {"type": "paragraph", "content": rich(*parts)}


def bullets(items):
    """items: list of part-lists (each a list of strings/tuples)."""
    return {"type": "bulletList", "content": [
        {"type": "listItem", "content": [{"type": "paragraph", "content": rich(*i)}]}
        for i in items
    ]}


def _cell(kind, parts, bold=False):
    if isinstance(parts, str):
        parts = [(parts, "strong")] if bold else [parts]
    return {"type": kind, "attrs": {},
            "content": [{"type": "paragraph", "content": rich(*parts)}]}


def table(headers, rows):
    content = [{"type": "tableRow",
                "content": [_cell("tableHeader", h, bold=True) for h in headers]}]
    for row in rows:
        content.append({"type": "tableRow",
                        "content": [_cell("tableCell", c) for c in row]})
    return {"type": "table", "attrs": {"isNumberColumnEnabled": False,
                                       "layout": "default"},
            "content": content}


def panel(kind, *parts):
    """kind: info | note | warning | success | error"""
    return {"type": "panel", "attrs": {"panelType": kind},
            "content": [{"type": "paragraph", "content": rich(*parts)}]}


def rule():
    return {"type": "rule"}


def doc(*nodes):
    return {"version": 1, "type": "doc", "content": list(nodes)}


def write(path, document):
    with open(path, "w") as fh:
        json.dump(document, fh, indent=2)
    return path
