#!/usr/bin/env python3
"""Render a source file with SSA names made explicit -- a debugging aid for
the SSA calculation itself (ql/lib/codeql/ada/dataflow/internal/SsaImpl.qll),
not a new analysis. Each write and each read of a tracked variable is shown
with a subscripted version number (X_1, X_2, ...), unique per (scope,
variable) in program order; each phi node is rendered as an inserted comment
at the position ql/lib/codeql/ada/test/SsaRenderAnnotations.qll already
anchors it at (the same one the SSA conformance tests check against).

See docs/ssa-design.md, "Renamed-source rendering", for the worked example
and the two anchoring traps (a phi's and a parameter entry write's own
location is the *whole* enclosing construct, not a point) that motivated
reusing that module rather than re-deriving positions here.

Usage (inside the WSL/Linux LAL build env, with `codeql` on PATH):
  python3 scripts/render_ssa.py path/to/file.adb
  python3 scripts/render_ssa.py path/to/project_dir --file path/to/project_dir/pkg.adb

Extracts a throwaway database (just the one file, or the given directory as
source root) and writes the rendered copy to <file>.ssa.adb alongside the
input -- never overwrites the original.
"""

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_EXTRACTOR_SEARCH_PATH = REPO_ROOT / "extractors"
DEFAULT_ADDITIONAL_PACKS = REPO_ROOT / "ql"
QUERY = REPO_ROOT / "ql" / "debug" / "PrintSsaRenamed.ql"


def run(cmd):
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    if proc.returncode != 0:
        sys.stderr.write(proc.stdout)
        sys.stderr.write(proc.stderr)
        raise SystemExit(f"command failed ({proc.returncode}): {' '.join(map(str, cmd))}")
    return proc


def build_database(codeql: str, source_root: Path, db_dir: Path) -> None:
    run([
        codeql, "database", "create", str(db_dir),
        "--language=ada", "--build-mode=none",
        f"--search-path={DEFAULT_EXTRACTOR_SEARCH_PATH}",
        f"--source-root={source_root}",
        "--overwrite",
    ])


def query_edits(codeql: str, db_dir: Path, tmp_dir: Path) -> list[dict]:
    bqrs_path = tmp_dir / "results.bqrs"
    run([
        codeql, "query", "run",
        f"--database={db_dir}",
        f"--additional-packs={DEFAULT_ADDITIONAL_PACKS}",
        f"--search-path={DEFAULT_EXTRACTOR_SEARCH_PATH}",
        f"--output={bqrs_path}",
        str(QUERY),
    ])
    proc = run([codeql, "bqrs", "decode", "--format=json", str(bqrs_path)])
    data = json.loads(proc.stdout)["#select"]
    columns = [c["name"] for c in data["columns"]]
    return [dict(zip(columns, row)) for row in data["tuples"]]


def apply_edits(source_path: Path, edits: list[dict]) -> str:
    """Applies `edits` (rows for this one file) to `source_path`'s text.

    Substitutions are applied right-to-left per line (descending startCol) so
    an earlier edit's column positions are never invalidated by an earlier
    (in application order) edit's length change -- CodeQL's location columns
    are 1-based and half-open (`[startCol, endCol)`, confirmed empirically:
    a 5-character identifier at column 4 reports startCol=4, endCol=9), so
    the 0-based Python slice is `[startCol - 1 : endCol - 1]`.
    """
    lines = source_path.read_text(encoding="utf-8").splitlines(keepends=True)
    by_line: dict[int, list[dict]] = {}
    for e in edits:
        by_line.setdefault(e["line"], []).append(e)

    for line_no, line_edits in by_line.items():
        idx = line_no - 1
        text = lines[idx]
        newline = ""
        if text.endswith("\n"):
            text, newline = text[:-1], "\n"

        substitutions = sorted(
            (e for e in line_edits if e["kind"] == "substitute"),
            key=lambda e: e["startCol"],
            reverse=True,
        )
        for e in substitutions:
            start, end = e["startCol"] - 1, e["endCol"] - 1
            text = text[:start] + e["text"] + text[end:]

        comments = [e["text"] for e in line_edits if e["kind"] == "comment"]
        if comments:
            text += "  --  " + "; ".join(comments)

        lines[idx] = text + newline

    return "".join(lines)


def main() -> int:
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("path", type=Path, help="An .adb/.ads file, or a directory to use as --source-root.")
    ap.add_argument("--file", type=Path,
                     help="When PATH is a directory, the specific file under it to render "
                          "(default: PATH itself, if PATH is a file).")
    ap.add_argument("--codeql", default=os.environ.get("CODEQL_BIN", "codeql"))
    ap.add_argument("--out", type=Path, help="Output path (default: <file>.ssa.adb next to the input).")
    args = ap.parse_args()

    if args.path.is_dir():
        source_root = args.path
        target_file = args.file
        if target_file is None:
            raise SystemExit("--file is required when PATH is a directory")
    else:
        source_root = args.path.parent
        target_file = args.path

    target_file = target_file.resolve()
    out_path = args.out or target_file.with_suffix(".ssa" + target_file.suffix)

    with tempfile.TemporaryDirectory(prefix="render_ssa_") as tmp:
        tmp_dir = Path(tmp)
        db_dir = tmp_dir / "db"
        build_database(args.codeql, source_root.resolve(), db_dir)
        edits = query_edits(args.codeql, db_dir, tmp_dir)

    file_edits = [e for e in edits if Path(e["file"]).resolve() == target_file]
    if not edits:
        print("warning: no SSA edits at all -- check the file actually extracted", file=sys.stderr)
    elif not file_edits:
        seen = sorted({e["file"] for e in edits})
        print(
            f"warning: no edits matched {target_file}; files seen: {seen}",
            file=sys.stderr,
        )

    rendered = apply_edits(target_file, file_edits)
    out_path.write_text(rendered, encoding="utf-8")
    print(f"wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
