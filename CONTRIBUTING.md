# Contributing

This covers the development environment, the code-generation pipeline behind
the dbscheme and QL classes, the test/regression suites, and the release
process. For how to write a query, see
[docs/query-writing.md](docs/query-writing.md); for how the extractor
behaves at runtime, see [docs/user-guide.md](docs/user-guide.md).

## Development environment

Anything that touches Libadalang — building it, running the extractor,
running `codeql test run` or the corpus regression — requires **WSL Debian
13** (not Ubuntu; Debian's packaged GNAT/gprbuild versions are what
`scripts/build-libadalang.sh` is written against, and Ubuntu's differ enough
to hit the same GNAT-version problems the script works around). Plain
`codeql pack`/compile-only work is fine on native Windows, but day-to-day
development happens in WSL.

Inside WSL:

```sh
apt-get install git build-essential gnat gprbuild python3 python3-venv \
  python3-dev libgmp-dev pkg-config libxmlada-dom-dev libxmlada-input-dev \
  libxmlada-sax-dev libxmlada-schema-dev libxmlada-unicode-dev

scripts/build-libadalang.sh   # ~45 min the first time; builds into $HOME/adacore

source ~/lal-venv/bin/activate
export PYTHONPATH=~/adacore/python LD_LIBRARY_PATH=~/adacore/lib
export PATH=~/tools/codeql:$PATH   # your CodeQL CLI install, 2.25.6
```

Run the full test suite from the repo root:

```sh
codeql test run ql/test --additional-packs=ql --search-path=extractors
```

If that exact invocation ever stops matching reality, `.github/workflows/ci.yml`
is the authoritative source — copy the step from there.

## The regeneration pipeline

The dbscheme, the generated QL classes, and the extractor's table map are
*all* derived from one input: a JSON dump of Libadalang's own node-kind
introspection. Nothing in this pipeline is hand-maintained except the two
scripts that drive it. Regenerate after a Libadalang upgrade (a
[pin bump](#bumping-the-libadalang-pin)) or if you suspect the checked-in
outputs have drifted from `schema/lal-nodes.json`:

```sh
python scripts/dump_lal_nodes.py > schema/lal-nodes.json
python generator/gen.py
```

`generator/gen.py` writes five files, all generated-but-committed (see
[docs/dbscheme-conventions.md](docs/dbscheme-conventions.md) for the naming
rules it follows):

- `extractors/ada/ada.dbscheme` and `ql/lib/ada.dbscheme` (identical copies)
- `ql/lib/codeql/ada/ast/internal/Raw.qll`
- `ql/lib/codeql/ada/ast/internal/RawMeta.qll` (accessor names and token text, used to print the AST)
- `extractors/ada/tools/ada_tables.json`

If the dbscheme's relations actually changed shape (adding/removing a
table, not just regenerating identical output), the query optimizer's
statistics file needs regenerating too, or query compilation fails:

```sh
codeql database create /tmp/stats-db --language=ada --build-mode=none \
  --search-path=extractors --source-root=tests/hello
codeql dataset measure /tmp/stats-db/db-ada -o ql/lib/ada.dbscheme.stats
```

(Any extracted database works as the input to `dataset measure` — using a
real corpus project instead of the minimal `tests/hello` fixture gives more
representative statistics, but for a mechanical regeneration after a schema
change, correctness matters more than representativeness.)

## Test suite and corpus regression

`codeql test run ql/test --additional-packs=ql --search-path=extractors`
(above) runs every query's fixture test plus the golden-output extractor
tests in `ql/test/extractor/`. This is fast (well under a minute) and should
pass before every commit.

`scripts/corpus_regression.py` is slower and different in kind: it runs the
*real* `codeql database create` pipeline (not a Libadalang-only spike)
against 5 pinned real-world Ada projects (`scripts/corpus.json`, fetched by
exact commit SHA) and compares file counts, node/xref/type counts, and
parse-error counts against `scripts/corpus_baseline.json`:

```sh
python3 scripts/corpus_regression.py               # all 5 projects
python3 scripts/corpus_regression.py --project gpr2 --project adasat
```

File-count drift or any new parse error is a hard failure — something
regressed. Name-resolution or timing drift is a warning only, since
Libadalang itself moves independently of this project (until a
[pin bump](#bumping-the-libadalang-pin) makes it deterministic again) and
can legitimately shift those numbers. If a change *should* move the
baseline (e.g. a deliberate extractor improvement that resolves more
references), regenerate it:

```sh
python3 scripts/corpus_regression.py --update-baseline
```

## CI notes

`.github/workflows/ci.yml` runs on every push/PR in a `debian:13` container,
matching the dev environment above exactly. Two caches make it fast on
repeat runs: the Libadalang build (keyed on
`hashFiles('scripts/build-libadalang.sh')`, so any edit to that script — a
[pin bump](#bumping-the-libadalang-pin), a new dependency — forces a full
~45 minute rebuild) and the downloaded CodeQL CLI (keyed on the pinned
version string). `LAL_CACHE_VERSION` is a manual escape hatch: bump it to
force a fresh Libadalang build *without* editing the script, for cases where
upstream `master` drifted in a way the script's own text doesn't capture.
Both caches use split `restore`/`save` steps rather than one combined
action, specifically so a good build still gets cached even if a later,
unrelated step (corpus regression network flakiness, say) fails the job —
see the comments in `ci.yml` for the exact mechanism.

## The executable-bit trap

Windows git does not track the Unix executable bit. Every *new* `.sh` file
needs it set explicitly before committing, or the Linux CI runner fails with
`EACCES` trying to exec it directly — this exact bug shipped once already
(see BURNDOWN.md Phase 5.4) and cost a debugging session because it's
invisible on Windows and even invisible in WSL when the repo lives under
`/mnt/c` (Windows-mounted paths report every file as `777` regardless of
git's tracked mode). Set it explicitly:

```sh
git update-index --chmod=+x path/to/new-script.sh
```

`git ls-files -s path/to/script.sh` shows the tracked mode directly
(`100755` = executable, `100644` = not) if you want to double-check before
committing — this is the only reliable way to verify it on Windows/WSL.

## Bumping the Libadalang pin

`scripts/build-libadalang.sh` builds every AdaCore dependency (Libadalang,
Langkit, GNATcoll, VSS, prettier-ada, AdaSAT, gprconfig_kb) from an exact
pinned commit SHA rather than a branch tip (decision D-012) — release builds
need to be reproducible, and letting these move independently made
corpus-regression name-resolution numbers drift for no reason tied to this
project's own changes. To bump a pin:

1. Update the relevant `*_COMMIT` variable near the top of
   `scripts/build-libadalang.sh`.
2. Commit. CI's cache key hashes this script's text, so the change forces a
   full rebuild automatically — no separate cache-busting step needed.
3. Once CI is green, run the [corpus regression](#test-suite-and-corpus-regression)
   and re-baseline if the numbers moved for a reason you expect.
4. Note the bump (and why) in the changelog.

Verify a pin bump locally before pushing by building fresh to a throwaway
prefix — the script's `PREFIX` is derived from `$HOME`, not independently
overridable, so redirect `$HOME` itself:

```sh
HOME=/tmp/lal-pin-test bash scripts/build-libadalang.sh
source /tmp/lal-pin-test/lal-venv/bin/activate
PYTHONPATH=/tmp/lal-pin-test/adacore/python \
  LD_LIBRARY_PATH=/tmp/lal-pin-test/adacore/lib \
  python3 -c "import libadalang; print(libadalang.__file__)"
rm -rf /tmp/lal-pin-test
```

CodeQL CLI support policy is simpler: whatever version `CODEQL_CLI_VERSION`
in `ci.yml` pins (2.25.6 as of this writing) is the only tested version.
Bumping it is a deliberate, separate change from a Libadalang pin bump.

## Release checklist

Releases are tag-driven (decision D-011): pushing a `vX.Y.Z` tag runs
`.github/workflows/release.yml`, which verifies the tag against the three
version-carrying manifests, runs the test suite, builds the release tarball,
publishes a GitHub Release with the tarball attached, and publishes both QL
packs to GHCR.

1. Bump the version in all three places, in one commit — the workflow
   refuses to release if they disagree with each other or with the tag:
   - `extractors/ada/codeql-extractor.yml` (`version:`)
   - `ql/lib/qlpack.yml` (`version:`)
   - `ql/src/qlpack.yml` (`version:`)
2. Push that commit, then **dry-run first**: trigger
   `.github/workflows/release.yml` manually (`workflow_dispatch`, e.g.
   `gh workflow run release.yml`) and confirm it goes green. This runs
   everything except the GitHub Release and pack-publish steps (guarded on
   an actual tag ref) and uploads the built tarball as a workflow artifact
   you can inspect before committing to a real release.
3. Only once the dry run is green: tag and push.
   ```sh
   git tag vX.Y.Z
   git push origin vX.Y.Z
   ```
4. Verify: the Actions run went green, the GitHub Release has the tarball
   attached, the GHCR packages page shows both `ada-all` and `ada-queries`
   at the new version, and a fresh download of the release asset actually
   works:
   ```sh
   curl -sSLO https://github.com/peter-villadsen/codeql-ada/releases/download/vX.Y.Z/codeql-extractor-ada-linux64.tar.gz
   tar xzf codeql-extractor-ada-linux64.tar.gz
   codeql database create /tmp/verify-db --language=ada --build-mode=none \
     --search-path=. --source-root=<any small Ada project>
   ```
