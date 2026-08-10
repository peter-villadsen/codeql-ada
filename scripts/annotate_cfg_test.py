#!/usr/bin/env python3
"""Transcribe actual CFG edges into inline expectation comments.

Runs a CFG conformance test, reads the "Unexpected result" rows it produces,
and appends the corresponding ``-- $ edge=...`` comment to each source line.

**This is a transcription tool, not an oracle.** It records what the CFG
implementation currently does. Run it only after checking the graph against the
rule in ``docs/cfg-design.md`` -- pasting its output over a rule it contradicts
turns the conformance test into a tautology. See "Workflow when adding or
changing a construct" in that document.

Lines already carrying a ``MISSING:`` or ``SPURIOUS:`` expectation are left
untouched and reported, so hand-written limitation tripwires are never
clobbered.

Usage (from the repo root, on the machine that can run the extractor):

    python scripts/annotate_cfg_test.py ql/test/library/Cfg/if-stmt
"""

from __future__ import annotations

import argparse
import io
import os
import re
import subprocess
import sys
from collections import defaultdict

# "| test.adb:3:4:9:11 | IfStmt | Unexpected result: edge=A\|true\|B |"
ROW = re.compile(
    r"^\+\|\s*(?P<file>[^:|]+):(?P<sl>\d+):(?P<sc>\d+):(?P<el>\d+):(?P<ec>\d+)\s*\|"
    r"[^|]*\|\s*Unexpected result:\s*(?P<value>.+?)\s*\|\s*$"
)

WSL_PREFIX = [
    "wsl.exe", "-d", "Debian", "-e", "bash", "-c",
]

RUN = (
    "cd {repo} && source /root/lal-venv/bin/activate && "
    "export PYTHONPATH=/root/adacore/python LD_LIBRARY_PATH=/root/adacore/lib "
    "PATH=/root/tools/codeql:$PATH && "
    "codeql test run {test} --additional-packs=ql --search-path=extractors"
)


def run_test(repo: str, test_dir: str) -> str:
    """Runs the conformance test and returns its combined output."""
    posix_repo = "/mnt/c" + os.path.abspath(repo)[2:].replace("\\", "/")
    cmd = RUN.format(repo=posix_repo, test=test_dir.replace("\\", "/"))
    if sys.platform == "win32":
        argv = WSL_PREFIX + [cmd]
    else:
        argv = ["bash", "-c", cmd]
    proc = subprocess.run(argv, capture_output=True, text=True)
    return proc.stdout + proc.stderr


def strip(test_dir: str) -> int:
    """Removes existing expectation comments so the run reports every edge.

    Without this, re-annotating a file keeps only the edges the run called
    "Unexpected" -- the ones that already matched are not reported, so they
    would be silently dropped. Lines carrying a hand-written `MISSING:` or
    `SPURIOUS:` expectation are left alone, matching `annotate`.
    """
    stripped = 0
    for name in sorted(os.listdir(test_dir)):
        if not name.endswith((".adb", ".ads")):
            continue
        path = os.path.join(test_dir, name)
        with io.open(path, encoding="utf-8") as f:
            lines = f.read().splitlines()
        out = [
            l if ("MISSING:" in l or "SPURIOUS:" in l) else re.sub(r"\s*--\s*\$ .*$", "", l)
            for l in lines
        ]
        if out != lines:
            stripped += 1
            with io.open(path, "w", encoding="utf-8", newline="\n") as f:
                f.write("\n".join(out) + "\n")
    return stripped


def collect(output: str) -> dict[tuple[str, int], list[str]]:
    """Maps (file, annotation line) to the expectation values to write there.

    The annotation line is the *end* line of the result location: the framework
    matches a comment's start line against the result's end line.
    """
    found: dict[tuple[str, int], set[str]] = defaultdict(set)
    for line in output.splitlines():
        m = ROW.match(line)
        if m:
            value = m.group("value").replace("\\|", "|")
            found[(m.group("file"), int(m.group("el")))].add(value)
    return {k: sorted(v) for k, v in found.items()}


def annotate(path: str, per_line: dict[int, list[str]]) -> tuple[int, list[int]]:
    """Appends expectation comments; returns (lines written, lines skipped)."""
    with io.open(path, encoding="utf-8") as f:
        lines = f.read().splitlines()

    written, skipped = 0, []
    for lineno, values in sorted(per_line.items()):
        idx = lineno - 1
        if idx >= len(lines):
            raise SystemExit(f"{path}: no line {lineno}")
        text = lines[idx]
        if "MISSING:" in text or "SPURIOUS:" in text:
            skipped.append(lineno)
            continue
        text = re.sub(r"\s*--\s*\$ .*$", "", text)
        lines[idx] = text + "  -- $ " + " ".join(values)
        written += 1

    with io.open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines) + "\n")
    return written, skipped


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("test_dir", help="conformance test directory, e.g. ql/test/library/Cfg/if-stmt")
    ap.add_argument("--repo", default=".", help="repository root (default: cwd)")
    args = ap.parse_args()

    strip(args.test_dir)
    output = run_test(args.repo, args.test_dir)
    if "Unexpected result" not in output:
        print("No unannotated edges. Either the test already passes, or it failed "
              "for another reason -- full output follows:\n")
        print(output)
        return 0

    per_file: dict[str, dict[int, list[str]]] = defaultdict(dict)
    for (fname, lineno), values in collect(output).items():
        per_file[fname][lineno] = values

    for fname, per_line in per_file.items():
        path = os.path.join(args.test_dir, fname)
        written, skipped = annotate(path, per_line)
        print(f"{path}: annotated {written} line(s)")
        if skipped:
            print(f"  left alone (hand-written MISSING/SPURIOUS): {skipped}")

    print("\nNow re-run the test, and re-read every annotation against "
          "docs/cfg-design.md before committing.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
