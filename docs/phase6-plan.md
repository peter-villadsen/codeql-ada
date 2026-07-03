# Phase 6 work plan — Packaging & release

All decisions for this phase are made (see [DECISIONS.md](../DECISIONS.md) D-009…D-012).
This document is the execution plan: each task is self-contained, lists the exact files to
touch, and ends with acceptance criteria that must pass before the task is "done".
**Do not re-open the decisions**; if a task turns out to be impossible as specified, stop and
report why instead of choosing a different design.

Task order: **6.0 → 6.4 → 6.1 → 6.2**; **6.3** any time after 6.0. (6.4 comes before 6.1/6.2
because release artifacts must be built from pinned sources.)

---

## Environment: where things run

- **Windows side** (`C:\Users\peter\source\repos\codeql-ada`): editing, git, CodeQL CLI at
  `C:\Users\peter\tools\codeql` — fine for `codeql pack` / compile-only work.
- **WSL Debian 13** (not Ubuntu): anything touching Libadalang or running the extractor.
  The repo is reachable at `/mnt/c/Users/peter/source/repos/codeql-ada`.
  Setup inside WSL:
  ```sh
  source /root/lal-venv/bin/activate
  export PYTHONPATH=/root/adacore/python LD_LIBRARY_PATH=/root/adacore/lib
  export PATH=/root/tools/codeql:$PATH   # Linux CodeQL CLI v2.25.6
  ```
  Libadalang install prefix inside WSL: `/root/adacore` (this is `ADA_LAL_PREFIX`).
- Full test suite (run from repo root, in WSL):
  `codeql test run ql/test --additional-packs=ql --search-path=extractors`
  (if that exact invocation fails, the authoritative form is in `.github/workflows/ci.yml` —
  copy it from there).

## Global traps (each has already cost a debugging session — respect them)

1. **Executable bits**: Windows git doesn't track the Unix exec bit. Every *new* `.sh` file
   must get `git update-index --chmod=+x <file>` before commit, or CI fails with `EACCES`.
2. **`ql/lib/ada.dbscheme.stats`** must stay in sync with `ql/lib/ada.dbscheme`. If the
   dbscheme changes (it should NOT in this phase), regenerate via `codeql dataset measure`.
3. **Extractor pack dir name must equal the language id** (`ada`), and `--search-path` points
   at the *parent* directory containing `ada/`.
4. **Don't unpin versions**: CodeQL CLI stays 2.25.6; CI cache keys hash
   `scripts/build-libadalang.sh`, so editing that script triggers a ~45 min LAL rebuild in CI
   — expected for 6.4, avoid otherwise.
5. **The CodeQL CLI is proprietary** — never bundle it in any artifact (D-001). Only
   Libadalang and its (Apache-2.0 / GPL-with-runtime-exception) deps may be bundled.
6. `ql/test`'s pack (`ada-tests`) is internal — never published.

---

## Task 6.0 — Rename pack scope to `peter-villadsen/` (D-009)

Small mechanical task.

1. In `ql/lib/qlpack.yml`, `ql/src/qlpack.yml`, `ql/test/qlpack.yml`: replace every
   `codeql-ada/` with `peter-villadsen/` (pack names *and* dependency keys — 5 occurrences).
2. `grep -rn "codeql-ada/"` over the repo to catch stragglers in docs/queries; update any that
   refer to *pack names* (leave references to the *repo* `peter-villadsen/codeql-ada` and
   plain "codeql-ada" prose alone).
3. Update D-007's placeholder note in `DECISIONS.md`? **No** — decision log entries are
   immutable; D-009 already supersedes it.

**Acceptance:** full test suite green in WSL (see Environment above).

## Task 6.4 — Pin Libadalang/Langkit commits (D-012)

`scripts/build-libadalang.sh` currently clones several repos at `master`/default-branch tip.
Make release builds reproducible:

1. In WSL, for each `git clone` in the script that doesn't already check out a fixed tag
   (langkit, libadalang, VSS, prettier-ada, gnatcoll-*, anything else at tip — gprbuild
   v25.0.0 and gpr2 v26.0.0 are already pinned tags, leave them): record the current commit
   SHA of the working local build (`git -C <checkout> rev-parse HEAD` under the build dir the
   script uses, or `git ls-remote` if checkouts are gone).
2. Add a pins block at the top of the script (`LANGKIT_COMMIT=<sha>` etc.) and a
   `git checkout <sha>` (or `git fetch origin <sha> && git checkout FETCH_HEAD`) after each
   corresponding clone. Keep the existing branch-name fix for prettier-ada (`main`).
3. Add a comment documenting the bump procedure: update SHA → CI cache key changes
   automatically (it hashes this script) → full rebuild → if corpus nameres numbers shift,
   re-baseline `scripts/corpus_baseline.json`. Note that `LAL_CACHE_VERSION` in `ci.yml` is
   now only needed to force rebuilds *without* script changes.
4. Verify with a **full from-scratch build** in WSL to a throwaway prefix:
   `PREFIX=/tmp/lal-pin-test scripts/build-libadalang.sh` (check the script's actual prefix
   variable name first), then `python -c "import libadalang"` against that prefix.
5. Push and confirm CI goes green (it will rebuild LAL — ~45 min — and must repopulate the
   cache).

**Acceptance:** script contains no un-pinned clones; from-scratch WSL build succeeds; CI green.

## Task 6.1 — Release tarball `codeql-extractor-ada-linux64.tar.gz` (D-010)

New script `scripts/create-extractor-pack.sh` (POSIX sh or bash, runs in WSL/Debian 13).
Inputs: `ADA_LAL_PREFIX` (default `$HOME/adacore`). Output: `extractor-pack/` directory and
the `.tar.gz`.

**Tarball layout** (extraction dir is what users pass to `--search-path`):

```
extractor-pack/
  ada/                        # copy of extractors/ada (dir name MUST be "ada", trap #3)
    codeql-extractor.yml
    ada.dbscheme
    tools/…                   # autobuild.sh, index.sh, extractor.py, ada_tables.json
    lal/                      # bundled Libadalang runtime (new)
      lib/…                   # shared libraries (see closure rule below)
      python/libadalang/…     # ctypes-based Python bindings from $PREFIX/python
      share/gpr/…             # only if autobuild.sh's GPR_PROJECT_PATH needs it at runtime
    THIRD_PARTY_NOTICES.md
    LICENSE                   # our MIT
```

Steps:

1. **Shared-library closure.** Start from `$PREFIX/lib/*` (copy all of it), then run `ldd` on
   `libadalang.so` and every other bundled `.so` and copy each resolved dependency that is
   **not** core glibc (exclude: `libc`, `libm`, `libpthread`, `libdl`, `librt`, `ld-linux*`,
   `libgcc_s` may stay excluded if present on Debian base — verify in step 5). This pulls in
   GNAT runtime libs (`libgnat-14.so`, `libgnarl-14.so`) from the FSF GNAT install — those
   MUST be bundled (target machines have no GNAT).
2. **Python bindings.** Copy `$PREFIX/python/libadalang` into `lal/python/`. First verify the
   bindings are pure-Python + ctypes (no `*.cpython-3XX-*.so` files inside) — expected true;
   if false, stop and report (it changes the "any Python ≥ 3.11" claim in D-010).
3. **`autobuild.sh`**: change the prefix default so a bundled runtime wins:
   `PREFIX="${ADA_LAL_PREFIX:-$CODEQL_EXTRACTOR_ADA_ROOT/lal}"` if that dir exists, else fall
   back to `$HOME/adacore` (keep dev workflow working). `index.sh` just execs `autobuild.sh`,
   so no change there.
4. **Cleanup**: do not ship `spike_extractor.py`; replace `autobuild.cmd` (stale spike
   leftover pointing at it) with an `echo`+`exit 1` stub saying native Windows is unsupported,
   use WSL (D-010). Do this in `extractors/ada` itself, not just the pack copy — check
   nothing else references `spike_extractor.py` before deleting it.
5. **`THIRD_PARTY_NOTICES.md`**: list Libadalang, Langkit, GNATcoll, XML/Ada, gpr2/libgpr,
   VSS, prettier-ada, AdaSAT (Apache-2.0, per component — verify each checkout's LICENSE in
   the WSL build tree) and the GNAT/GCC runtime libraries (GPL-3.0 WITH
   GCC-exception-3.1 — the exception is what permits redistribution here; say so). Include or
   link full license texts.
6. **Tar**: `tar -C extractor-pack -czf codeql-extractor-ada-linux64.tar.gz ada` — tar
   preserves exec bits, but confirm `autobuild.sh`/`index.sh` are `+x` inside the archive
   (`tar -tvzf`).
7. **Isolation verification** (the acceptance test — proves nothing leaks from the dev
   machine's `/root/adacore` or venv). In WSL:
   ```sh
   tar -xzf codeql-extractor-ada-linux64.tar.gz -C /tmp/pack-test
   env -i HOME=/tmp/pack-test PATH=/usr/bin:/bin \
     /root/tools/codeql/codeql database create /tmp/pack-test/db \
       --language=ada --build-mode=none --search-path=/tmp/pack-test \
       --source-root=tests/hello
   ```
   Then run one real query against the DB (e.g. `ql/src/queries/ExceptionSwallowing.ql` via
   `codeql query run`) and check it returns rows/compiles. If Debian's system `python3` in
   that clean env is < 3.11 or missing modules, that's a real finding — the tarball must work
   with stock `apt install python3` on Debian 13, nothing more.
8. Ideally repeat step 7 in a fresh `docker run debian:13` container (only `python3` +
   CodeQL CLI installed) if Docker is available in WSL; if not, the `env -i` test suffices.

**Acceptance:** step 7 passes; `tar -tvzf` shows exec bits; NOTICES file present; the normal
test suite still green (the autobuild.sh change must not break dev-mode extraction).

## Task 6.2 — Release workflow: GitHub Release + `codeql pack publish` (D-011)

New `.github/workflows/release.yml`, triggered on tag push `v*`. Reuse the structure of
`ci.yml` (same `container: debian:13`, same apt prereqs, same LAL restore/build/save cache
steps and CodeQL CLI cache steps — copy them verbatim, including the split
restore/save pattern and its `if:` conditions).

Job steps after the environment is up:

1. **Version-consistency gate**: extract versions from `extractors/ada/codeql-extractor.yml`,
   `ql/lib/qlpack.yml`, `ql/src/qlpack.yml`; all three must equal the tag minus the leading
   `v`, else fail fast.
2. **Test gate**: run the same `codeql test run` step as `ci.yml`.
3. **Build tarball**: `scripts/create-extractor-pack.sh` (task 6.1), with
   `ADA_LAL_PREFIX` pointing at the CI LAL prefix (same env as ci.yml's test step).
4. **Create GitHub Release** with the tarball attached: use `softprops/action-gh-release@v2`
   (works inside container jobs; no `gh` CLI needed) with `files:
   codeql-extractor-ada-linux64.tar.gz` and `generate_release_notes: true`.
5. **Publish QL packs** (lib first — src depends on it):
   ```sh
   codeql pack install ql/src   # resolves the local ada-all via --additional-packs if needed
   codeql pack publish ql/lib --github-auth-stdin <<< "$GITHUB_TOKEN"
   codeql pack publish ql/src --github-auth-stdin <<< "$GITHUB_TOKEN"
   ```
   (Exact auth flag: check `codeql pack publish --help` on 2.25.6 — `--github-auth-stdin` or
   the `GITHUB_TOKEN` env var; use whichever the pinned CLI supports.) Never publish
   `ql/test`.
6. Workflow `permissions:`: `contents: write` (release), `packages: write` (GHCR).

Also add a short "Release checklist" section to `CONTRIBUTING.md` (task 6.3 file): bump the
three version fields in one commit → push → tag `vX.Y.Z` → push tag → verify the workflow,
the GHCR packages page, and that
`codeql database create --search-path` works against the downloaded release asset.

**Dry-run before real tag:** add `workflow_dispatch:` as a second trigger that runs
everything except steps 4–5 (guard those with `if: startsWith(github.ref, 'refs/tags/')`), so
the build can be validated on `master` without publishing. First real publish: tag `v0.1.0`
(bump manifests from 0.0.1), **but let the user pull the trigger — prepare everything, do not
push the tag yourself.**

**Acceptance:** `workflow_dispatch` run green on GitHub Actions (builds tarball as artifact,
skips publish steps); version-gate step demonstrably fails on mismatch (test locally by
running its shell snippet with a wrong tag value, no need to push a bad tag).

## Task 6.3 — Documentation (D-010, D-011, D-012)

Four files. Source material: BURNDOWN.md phase entries, DECISIONS.md, and the scripts
themselves — everything documented must be verified against the actual code, not guessed.

1. **`README.md` rewrite**: drop the "pre-alpha / nothing usable" status; new status =
   "working extractor + 8 queries, tested on a 5-project corpus, releases pending". Quickstart
   (download tarball → extract → `codeql database create --language=ada --build-mode=none
   --search-path=<dir> --source-root=<project>` → `codeql database analyze` with
   `peter-villadsen/ada-queries`). Requirements box: Linux x86_64 (Debian-13-era glibc),
   Python ≥ 3.11, user-supplied CodeQL CLI (2.25.6 tested), WSL for Windows. Keep the
   existing License section as is.
2. **`docs/user-guide.md`**: everything in the quickstart, expanded — GPR selection
   (`CODEQL_EXTRACTOR_ADA_GPR` env var → single-GPR autodetect → auto unit provider
   fallback and what each means for name-resolution quality), parallelism
   (`CODEQL_EXTRACTOR_ADA_JOBS`, default nproc), parse errors land in `diagnostics` not
   failures, database rebuild policy pre-1.0 (D-011), known limitation: same-kind-same-span
   node merging.
3. **`docs/query-writing.md`**: pack layout (`ada-all` lib / `ada-queries` src); the two API
   layers — generated `Raw.qll` (405 classes, mirrors Libadalang node kinds; link
   `docs/dbscheme-conventions.md`) vs the hand layer in `ada.qll` (`Name.getText()`,
   `Name.getReferencedDecl()`, `Expr.getType()`, `BasicDecl.getADefiningName()/getAName()/
   isReferenced()`, `AdaNode.getEnclosingSubprogram()/getEnclosingUnit()`, `Comment`); how to
   add a query + test (`ql/src/queries/X.ql`, `ql/test/queries/X/` with `.qlref`, Ada
   snippet, `.expected`; `codeql test run --learn` to bootstrap expected output); point at the
   8 existing queries as templates.
4. **`CONTRIBUTING.md`**: dev env (WSL Debian 13 required, `scripts/build-libadalang.sh`,
   ~45 min, venv/env vars from the Environment section above); the regeneration pipeline
   (`scripts/dump_lal_nodes.py` → `schema/lal-nodes.json` → `generator/gen.py` →
   dbscheme/Raw.qll/ada_tables.json, plus `ada.dbscheme.stats` via `codeql dataset measure`);
   test suite + corpus regression (`scripts/corpus_regression.py`, baseline re-baselining
   rules); CI notes (cache keys, `LAL_CACHE_VERSION`); the exec-bit trap; pin-bump procedure
   (D-012); release checklist (from task 6.2).

**Acceptance:** every command in the docs has been executed once as written (copy-paste
fidelity); links resolve; no reference to the old `codeql-ada/` pack scope remains.

---

## Explicitly out of scope for Phase 6

- Native Windows / macOS extractor builds (D-010) — do not attempt.
- dbscheme upgrade scripts (D-011) — rebuild policy instead.
- CFG/dataflow (burndown 4.3/4.4), new queries, generic instance-body modeling — post-v1.
- A `codeql-extractor-action`-style composite GitHub Action for consumers — nice-to-have,
  only after a first release exists; needs no decisions now.
