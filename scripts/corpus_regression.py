"""Corpus regression (burndown 5.3): extract pinned real-world Ada projects
with the actual `codeql database create` pipeline and check for regressions.

Unlike scripts/spike_nameres.py (which drives Libadalang directly), this
exercises the full extractor as CodeQL invokes it, so it also catches TRAP/
dbscheme/CLI-contract breakage, not just Libadalang-level issues.

Usage (inside the WSL/Linux LAL build env, with `codeql` on PATH or --codeql):
  python3 scripts/corpus_regression.py
  python3 scripts/corpus_regression.py --project gpr2 --project adasat
  python3 scripts/corpus_regression.py --update-baseline

Corpus projects and pinned commits: scripts/corpus.json
Recorded baseline stats:            scripts/corpus_baseline.json
"""

import argparse
import ast
import json
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_CONFIG = REPO_ROOT / "scripts" / "corpus.json"
DEFAULT_BASELINE = REPO_ROOT / "scripts" / "corpus_baseline.json"
DEFAULT_EXTRACTOR_SEARCH_PATH = REPO_ROOT / "extractors"

# CodeQL relays the extractor's stdout through its own logging, prefixing each
# line with a timestamp and a "[build-stdout]" tag, so this deliberately does
# not anchor to the start of the line.
STATS_RE = re.compile(
    r"\[ada-extractor\] (\d+) files in ([\d.]+)s(?: \((\d+) jobs\))?: (\{.*\})$",
    re.MULTILINE,
)

# Fields tracked in the baseline / compared run-over-run.
TRACKED_FIELDS = ("files", "nodes", "xref", "types", "diags", "nameres_errors")


def load_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def ensure_checkout(cache_dir: Path, project: dict) -> Path:
    """Clone (or reuse) the project pinned at its exact commit SHA.

    Fetches by SHA rather than `--depth 1` off a branch tip, so re-runs (and
    CI runs months later) extract the identical bytes the baseline was
    recorded against. Requires the remote to allow fetching arbitrary
    reachable commits, which GitHub does for public repos.
    """
    dest = cache_dir / project["name"]
    ref = project["ref"]
    if (dest / ".git").is_dir():
        current = subprocess.run(
            ["git", "-C", str(dest), "rev-parse", "HEAD"],
            capture_output=True, text=True, check=False,
        ).stdout.strip()
        if current == ref:
            return dest
        shutil.rmtree(dest)

    dest.mkdir(parents=True, exist_ok=True)
    subprocess.run(["git", "init", "-q", str(dest)], check=True)
    subprocess.run(
        ["git", "-C", str(dest), "remote", "add", "origin", project["repo"]],
        check=True,
    )
    subprocess.run(
        ["git", "-C", str(dest), "fetch", "-q", "--depth", "1", "origin", ref],
        check=True,
    )
    subprocess.run(["git", "-C", str(dest), "checkout", "-q", ref], check=True)
    return dest


def run_extraction(codeql_bin: str, repo_dir: Path, gpr, db_dir: Path, jobs: int):
    env = os.environ.copy()
    env["CODEQL_EXTRACTOR_ADA_JOBS"] = str(jobs)
    if gpr:
        env["CODEQL_EXTRACTOR_ADA_GPR"] = str(repo_dir / gpr)
    else:
        env.pop("CODEQL_EXTRACTOR_ADA_GPR", None)

    if db_dir.exists():
        shutil.rmtree(db_dir)

    cmd = [
        codeql_bin, "database", "create", str(db_dir),
        "--language=ada", "--build-mode=none",
        f"--search-path={DEFAULT_EXTRACTOR_SEARCH_PATH}",
        f"--source-root={repo_dir}",
        "--overwrite",
    ]
    t0 = time.monotonic()
    proc = subprocess.run(cmd, env=env, capture_output=True, text=True, check=False)
    wall = time.monotonic() - t0
    return proc.returncode, wall, proc.stdout + proc.stderr


def parse_stats(output: str):
    matches = STATS_RE.findall(output)
    if not matches:
        return None
    files, seconds, _jobs, totals_repr = matches[-1]
    totals = ast.literal_eval(totals_repr)
    stats = {"files": int(files), "extractor_seconds": float(seconds)}
    stats.update(totals)
    return stats


def compare_to_baseline(name: str, stats: dict, baseline: dict):
    """Returns (failures, warnings) — both lists of strings."""
    failures, warnings = [], []
    prev = baseline.get(name)
    if prev is None:
        warnings.append("no baseline recorded yet (run --update-baseline)")
        return failures, warnings

    if stats["files"] != prev["files"]:
        failures.append(
            f"file count changed {prev['files']} -> {stats['files']} "
            "(ref is pinned; this means extractor discovery logic changed)"
        )
    if stats["diags"] > prev["diags"]:
        failures.append(f"parse errors increased {prev['diags']} -> {stats['diags']}")

    prev_nameres = prev.get("nameres_errors", 0)
    if stats["nameres_errors"] > prev_nameres * 1.05 + 5:
        warnings.append(
            f"nameres_errors increased {prev_nameres} -> {stats['nameres_errors']} "
            "(likely a Libadalang version drift, since LAL is built from a moving "
            "branch tip — not necessarily this repo's fault)"
        )
    prev_seconds = prev.get("extractor_seconds", 0)
    if prev_seconds and stats["extractor_seconds"] > prev_seconds * 2:
        warnings.append(
            f"extraction time doubled {prev_seconds:.1f}s -> "
            f"{stats['extractor_seconds']:.1f}s"
        )
    return failures, warnings


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--config", type=Path, default=DEFAULT_CONFIG)
    ap.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    ap.add_argument("--update-baseline", action="store_true",
                     help="Overwrite the baseline with this run's stats instead of comparing.")
    ap.add_argument("--cache-dir", type=Path,
                     default=Path(os.environ.get("CORPUS_CACHE_DIR",
                                                  Path.home() / ".cache" / "codeql-ada-corpus")))
    ap.add_argument("--codeql", default=os.environ.get("CODEQL_BIN", "codeql"))
    ap.add_argument("--jobs", type=int, default=os.cpu_count() or 1)
    ap.add_argument("--project", action="append", dest="projects",
                     help="Restrict to named project(s); repeatable. Default: all.")
    ap.add_argument("--out", type=Path, help="Write the full JSON report here.")
    args = ap.parse_args()

    config = load_json(args.config)
    all_projects = config["projects"]
    if args.projects:
        wanted = set(args.projects)
        all_projects = [p for p in all_projects if p["name"] in wanted]
        missing = wanted - {p["name"] for p in all_projects}
        if missing:
            sys.exit(f"unknown project(s): {', '.join(sorted(missing))}")

    baseline = load_json(args.baseline) if args.baseline.exists() else {}
    args.cache_dir.mkdir(parents=True, exist_ok=True)

    report = {}
    any_failures = False

    print(f"{'project':<20} {'files':>7} {'nodes':>9} {'xref':>8} {'types':>8} "
          f"{'diags':>6} {'nameres_err':>12} {'time(s)':>8}  status")
    for project in all_projects:
        name = project["name"]
        try:
            repo_dir = ensure_checkout(args.cache_dir, project)
            db_dir = args.cache_dir / f"{name}-db"
            rc, wall, output = run_extraction(
                args.codeql, repo_dir, project.get("gpr"), db_dir, args.jobs
            )
        except subprocess.CalledProcessError as exc:
            report[name] = {"error": str(exc)}
            any_failures = True
            print(f"{name:<20} {'--':>7} setup failed: {exc}")
            continue

        stats = parse_stats(output)
        entry = {"returncode": rc, "wall_seconds": wall}
        if stats:
            entry.update(stats)
        report[name] = entry

        if rc != 0 or stats is None:
            any_failures = True
            status = f"FAIL (exit {rc}, {'no stats parsed' if stats is None else ''})"
            print(f"{name:<20} extraction failed: {status}")
            print(output[-4000:])
            continue

        if args.update_baseline:
            status = "recorded"
        else:
            failures, warnings = compare_to_baseline(name, stats, baseline)
            entry["failures"] = failures
            entry["warnings"] = warnings
            if failures:
                any_failures = True
                status = "FAIL: " + "; ".join(failures)
            elif warnings:
                status = "WARN: " + "; ".join(warnings)
            else:
                status = "ok"

        print(f"{name:<20} {stats['files']:>7} {stats['nodes']:>9} {stats['xref']:>8} "
              f"{stats['types']:>8} {stats['diags']:>6} {stats['nameres_errors']:>12} "
              f"{stats['extractor_seconds']:>8.1f}  {status}")

    if args.update_baseline:
        new_baseline = {
            name: {k: v[k] for k in TRACKED_FIELDS if k in v} |
                  {"extractor_seconds": v.get("extractor_seconds", 0)}
            for name, v in report.items() if "nodes" in v
        }
        args.baseline.write_text(
            json.dumps(new_baseline, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
        print(f"\nWrote baseline for {len(new_baseline)} project(s) to {args.baseline}")

    if args.out:
        args.out.write_text(json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8")

    return 1 if any_failures else 0


if __name__ == "__main__":
    sys.exit(main())
