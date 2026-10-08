"""Print the AST of an Ada database as indented text, JSON or XML.

Runs ql/lib/tools/PrintAstRows.ql (one row per node, in pre-order) and rebuilds the
tree from it: the same tree as VS Code's "View AST" and tools/PrintAst.ql, in terms a
query uses -- each node's Raw class, its token text, the declaration a name resolves
to, and the accessor (`getSuffix`) or list index (`[0]`) that reaches it.

Usage (inside the WSL/Linux env, with `codeql` on PATH or --codeql):
  python3 scripts/print_ast.py <db>                              # every file, text
  python3 scripts/print_ast.py <db> --file adasat-formulas.adb   # one file
  python3 scripts/print_ast.py <db> --file a.adb --file b.ads --format json --out ast.json
  python3 scripts/print_ast.py <db> --format xml

--file takes a path suffix (`formulas.adb` does not match `adasat-formulas.adb`; use
the whole name or more of the path). Predefined pseudo-sources are never printed.

A database open in VS Code is locked by the extension's query server; close it there
first, or pass --copy-db to run on a temporary copy.
"""

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
QUERY = REPO_ROOT / "ql" / "lib" / "tools" / "PrintAstRows.ql"

COLUMNS = ["path", "row", "depth", "edge", "nodeClass", "text", "targets",
           "startLine", "startColumn", "endLine", "endColumn"]


def run(cmd: list[str]) -> str:
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        out = proc.stdout + proc.stderr
        if "already locked by another running process" in out:
            sys.exit("error: the database is locked, probably by VS Code's CodeQL query "
                     "server; close it there or pass --copy-db")
        sys.exit(f"error: {' '.join(cmd[:3])} failed:\n{out}")
    return proc.stdout


def query_rows(codeql: str, db: Path, files: list[str], work: Path) -> list[dict]:
    """Runs the rows query and returns its rows as dicts keyed by COLUMNS."""
    selected = work / "selected.csv"
    # One quoted path suffix per line; an empty file selects every file.
    selected.write_text("".join('"' + f.replace('"', '""') + '"\n' for f in files))
    bqrs = work / "rows.bqrs"
    run([codeql, "query", "run", f"--database={db}", f"--additional-packs={REPO_ROOT / 'ql'}",
         f"--external=selectedFile={selected}", f"--output={bqrs}", str(QUERY)])
    decoded = json.loads(run([codeql, "bqrs", "decode", "--format=json", str(bqrs)]))
    return [dict(zip(COLUMNS, t)) for t in decoded["#select"]["tuples"]]


def build_trees(rows: list[dict]) -> dict[str, list[dict]]:
    """Gets each file's compilation units as nested nodes, from rows in pre-order."""
    trees: dict[str, list[dict]] = {}
    stack: list[dict] = []  # the current node's ancestors, by depth
    for r in sorted(rows, key=lambda r: (r["path"], r["row"])):
        node = {
            "edge": r["edge"] or None,
            "class": r["nodeClass"],
            "text": r["text"] or None,
            "resolvesTo": r["targets"].split("\n") if r["targets"] else [],
            "start": f'{r["startLine"]}:{r["startColumn"]}',
            "end": f'{r["endLine"]}:{r["endColumn"]}',
            "children": [],
        }
        del stack[r["depth"]:]
        if stack:
            stack[-1]["children"].append(node)
        else:
            trees.setdefault(r["path"], []).append(node)
        stack.append(node)
    return trees


def format_text(trees: dict[str, list[dict]]) -> str:
    lines = []

    def walk(node: dict, depth: int) -> None:
        label = node["class"]
        if node["text"]:
            label += " " + node["text"]
        if node["resolvesTo"]:
            label += " -> " + " | ".join(node["resolvesTo"])
        edge = node["edge"] + ": " if node["edge"] else ""
        lines.append(f"{node['start']:>9}  {'  ' * depth}{edge}{label}")
        for child in node["children"]:
            walk(child, depth + 1)

    for path, units in trees.items():
        lines.append(f"== {path}")
        for unit in units:
            walk(unit, 0)
    return "\n".join(lines) + "\n"


def format_json(trees: dict[str, list[dict]]) -> str:
    def clean(node: dict) -> dict:
        out = {k: v for k, v in node.items() if v not in (None, []) and k != "children"}
        if node["children"]:
            out["children"] = [clean(c) for c in node["children"]]
        return out

    doc = {"files": [{"path": p, "units": [clean(u) for u in units]} for p, units in trees.items()]}
    return json.dumps(doc, indent=2) + "\n"


def format_xml(trees: dict[str, list[dict]]) -> str:
    # Element names are the Raw classes, which are valid XML names.
    def element(parent: ET.Element, node: dict) -> None:
        e = ET.SubElement(parent, node["class"])
        if node["edge"]:
            e.set("edge", node["edge"])
        if node["text"]:
            e.set("text", node["text"])
        if node["resolvesTo"]:
            e.set("resolvesTo", " | ".join(node["resolvesTo"]))
        e.set("start", node["start"])
        e.set("end", node["end"])
        for child in node["children"]:
            element(e, child)

    root = ET.Element("ast")
    for path, units in trees.items():
        f = ET.SubElement(root, "file", path=path)
        for unit in units:
            element(f, unit)
    ET.indent(root)
    return ET.tostring(root, encoding="unicode", xml_declaration=True) + "\n"


FORMATS = {"text": format_text, "json": format_json, "xml": format_xml}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("database", type=Path, help="an Ada CodeQL database")
    ap.add_argument("--file", action="append", default=[],
                    help="path suffix of a file to print (repeatable; default: every file)")
    ap.add_argument("--format", choices=FORMATS, default="text")
    ap.add_argument("--out", type=Path, help="write here instead of stdout")
    ap.add_argument("--codeql", default="codeql", help="CodeQL CLI (default: codeql on PATH)")
    ap.add_argument("--copy-db", action="store_true",
                    help="run on a temporary copy of the database (when VS Code has it open)")
    args = ap.parse_args()

    if not (args.database / "codeql-database.yml").is_file():
        sys.exit(f"error: {args.database} is not a CodeQL database")
    with tempfile.TemporaryDirectory(prefix="print_ast-") as tmp:
        work = Path(tmp)
        db = args.database
        if args.copy_db:
            db = work / "db"
            shutil.copytree(args.database, db, ignore=shutil.ignore_patterns(".lock"))
        rows = query_rows(args.codeql, db, args.file, work)
    if not rows:
        sys.exit("error: no file matched" if args.file else "error: the database has no source files")
    output = FORMATS[args.format](build_trees(rows))
    if args.out:
        args.out.write_text(output)
    else:
        sys.stdout.write(output)


if __name__ == "__main__":
    main()
