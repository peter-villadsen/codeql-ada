"""Corpus query results (Task 9.6): run the query suite over the corpus databases
that scripts/corpus_regression.py builds, and count results per query.

Usage (inside the WSL/Linux env, with `codeql` on PATH or --codeql):
  python3 scripts/corpus_queries.py                      # compare to the baseline
  python3 scripts/corpus_queries.py --update-baseline    # record this run instead
  python3 scripts/corpus_queries.py --project alire --out /root/q.json

Run scripts/corpus_regression.py first: it (re)builds <cache>/<project>-db. The SARIF
for each project is kept in --sarif-dir for triage. Recorded counts:
scripts/corpus_query_baseline.json. A count that changes is reported, not failed:
whether a change is an improvement is a triage question.
"""

import argparse
import json
import os
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = REPO_ROOT / "scripts" / "corpus.json"
DEFAULT_BASELINE = REPO_ROOT / "scripts" / "corpus_query_baseline.json"


def analyze(codeql: str, db: Path, sarif: Path) -> tuple[int, float, str]:
    cmd = [
        codeql, "database", "analyze", str(db), str(REPO_ROOT / "ql" / "src"),
        f"--additional-packs={REPO_ROOT / 'ql'}",
        f"--search-path={REPO_ROOT / 'extractors'}",
        "--format=sarif-latest", f"--output={sarif}", "--rerun",
    ]
    t0 = time.monotonic()
    proc = subprocess.run(cmd, capture_output=True, text=True, check=False)
    return proc.returncode, time.monotonic() - t0, proc.stdout + proc.stderr


def count_results(sarif: Path) -> Counter:
    data = json.loads(sarif.read_text(encoding="utf-8"))
    counts = Counter()
    for run in data.get("runs", []):
        for rule in run.get("tool", {}).get("driver", {}).get("rules", []):
            counts[rule["id"]] += 0  # every rule appears, even with no results
        for result in run.get("results", []):
            counts[result["ruleId"]] += 1
    return counts


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    ap.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--cache-dir", type=Path,
                    default=Path(os.environ.get("CORPUS_CACHE_DIR",
                                                Path.home() / ".cache" / "codeql-ada-corpus")))
    ap.add_argument("--sarif-dir", type=Path, default=Path.home() / "corpus-sarif")
    ap.add_argument("--codeql", default=os.environ.get("CODEQL_BIN", "codeql"))
    ap.add_argument("--project", action="append", dest="projects")
    ap.add_argument("--out", type=Path, help="Write the full JSON report here.")
    args = ap.parse_args()

    projects = [p["name"] for p in json.loads(args.config.read_text())["projects"]]
    if args.projects:
        projects = [p for p in projects if p in set(args.projects)]
    baseline = json.loads(args.baseline.read_text()) if args.baseline.exists() else {}
    args.sarif_dir.mkdir(parents=True, exist_ok=True)

    report, failed = {}, False
    for name in projects:
        db = args.cache_dir / f"{name}-db"
        sarif = args.sarif_dir / f"{name}.sarif"
        rc, secs, output = analyze(args.codeql, db, sarif)
        if rc != 0:
            failed = True
            report[name] = {"error": output[-2000:]}
            print(f"{name}: database analyze failed (rc={rc})\n{output[-2000:]}")
            continue
        counts = count_results(sarif)
        report[name] = {"seconds": round(secs, 1), "total": sum(counts.values()),
                        "results": dict(sorted(counts.items()))}
        print(f"{name}: {sum(counts.values())} results in {secs:.0f}s")

    rules = sorted({r for e in report.values() for r in e.get("results", {})})
    print(f"\n{'query':<34}" + "".join(f"{p[:12]:>13}" for p in projects))
    for rule in rules:
        cells = []
        for p in projects:
            now = report.get(p, {}).get("results", {}).get(rule)
            before = baseline.get(p, {}).get("results", {}).get(rule)
            cell = "-" if now is None else str(now)
            if not args.update_baseline and before is not None and now != before:
                cell += f" ({before})"
            cells.append(f"{cell:>13}")
        print(f"{rule:<34}" + "".join(cells))
    totals = [str(report.get(p, {}).get("total", "-")) for p in projects]
    print(f"{'TOTAL':<34}" + "".join(f"{t:>13}" for t in totals))
    if not args.update_baseline and baseline:
        print("\n(n) = baseline count where it differs")

    if args.out:
        args.out.write_text(json.dumps(report, indent=1), encoding="utf-8")
    if args.update_baseline and not failed:
        args.baseline.write_text(
            json.dumps({p: {"results": e["results"], "total": e["total"]}
                        for p, e in report.items()}, indent=1, sort_keys=True) + "\n",
            encoding="utf-8")
        print(f"baseline written to {args.baseline}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
