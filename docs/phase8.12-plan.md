# Burndown 8.12 — predefined and runtime entities: spike findings and plan

Spike run 2026-09-25 with `scripts/spike_standard.py` plus a throwaway two-pass prototype
of the extractor (not committed; its design is recorded in §3.2). Environment as in
`docs/phase9.2-plan.md` §1 (WSL Debian, GNAT 14 runtime at
`/usr/lib/gcc/x86_64-linux-gnu/14/adainclude`, Libadalang per D-012).

**Headline: 8.12 was framed as "extract `Standard`", but the larger problem is that under
the auto unit provider the GNAT runtime is not visible at all, and that corrupts name
resolution of *user* code, not just of runtime entities.** It produces hundreds of false
positives per project in the shipped `unused-*` / `dead-local-subprogram` queries today.
Fixing that (8.12a) is small and independent of extracting anything (8.12b).

---

## 1. Findings

### 1.1 Without the runtime, statements that mention it fail to resolve at all

The extractor's fallback (`lal.UnitProvider.auto(input_files=...)`) knows only the project
files. `with Ada.Command_Line;` is then unresolvable, and Libadalang's resolution of any
statement or declaration that mentions a runtime entity fails as a whole, raising
`PropertyError` or returning nothing for the *user's own* names in it too. On the probe
fixture, `String`, `Integer` and a local type `Word` all failed only because they shared
a declaration with a runtime reference.

A GPR project (`lal.GPRProject`) finds the toolchain's runtime by itself; the auto
provider finds it when the runtime specs are simply added to `input_files`. Four of the
five corpus projects use the auto provider (see `scripts/corpus.json`), and so will most
users without a buildable `.gpr`.

Identifier resolution (non-defining `Identifier`s, `spike_standard.py closure`):

| Project | Provider | Resolved | Unresolved | `PropertyError` |
| --- | --- | --- | --- | --- |
| adasat | GPR | 93.1% | 6.9% | 0.0% |
| libkeccak | auto | 58.4% | 14.6% | 27.1% |
| libkeccak | auto + runtime | 85.6% | 9.1% | 5.3% |
| libadalang-tools | auto | 43.5% | 21.1% | 35.4% |

The corpus baseline had been tracking this all along without it being diagnosed:
`nameres_errors` in `scripts/corpus_baseline.json` is 84,917 (alire), 205,122 (gpr2),
66,501 (libadalang-tools), against 0 for the GPR project.

### 1.2 The consequence: false positives in shipped queries

Full query suite, current extractor vs. the prototype (runtime visible *and* direct
targets extracted), `codeql database analyze` CSV diff:

| Project | Results lost | New results | Notable |
| --- | --- | --- | --- |
| libkeccak | 322 | 0 | unused-parameter 155 → 10, unused-local 181 → 8, dead-local-subprogram 11 → 7 |
| adasat (auto provider) | 12 | 0 | unused-local 9 → 0 |
| alire | 748 | 12 | unused-parameter 1322 → 904, unused-local 1110 → 832, dead-local 176 → 125 |

Spot-checked: libkeccak `ascon.adb:74-75` reports `S` and `Data` as unused parameters;
both are used a dozen times in that body, in statements mentioning `Interfaces`
(`Unsigned_64`, `Shift_Left`). The lost results are false positives.

### 1.3 The 12 new alire results expose two latent query bugs

Resolution that used to fail now succeeds, and two queries turn out to be wrong in ways
the failures were hiding:

- **`self-comparison` / `identical-operands` compare only the referenced declaration.**
  `L.Size = R.Size` (`alire-cache.ads:106`) and `This.Added.Is_Empty and then
  This.Removed.Is_Empty` (`alire-dependencies-diffs.adb:52`) are reported because both
  sides select the same component or function; the differing prefix is ignored. Same bug
  for in-source record components, so it predates this work.
- **Multi-identifier declarations (the D-024 problem) in those same queries.**
  `Wanted <= Actual` (`alire-roots.adb:47`) is reported because `Wanted, Actual :
  Stop_Points` is one `BasicDecl`, so both names resolve to it. The SSA layer already
  solved this (D-024: narrow by name text within the declaration); these queries don't.
- `direct-recursion` gained 6 results (`alire-conditional_trees.adb:136`,
  `alire-origins-tweaks.adb:67`, ...). All involve overloaded names, and they are **not
  triaged**; do that in 8.12a.

8.12a must fix these in the same change, or it swaps several hundred false positives
for a smaller set of new ones.

### 1.4 `Standard` is a real, extractable unit — with a misleading path

`root.p_standard_unit` is an ordinary `AnalysisUnit`: 134 lines of real Ada text, 1,800
nodes, no diagnostics, normal source locations. The existing `walk()` extracts it
unchanged. Two catches:

- **Its filename is `<cwd>/__standard`.** Libadalang makes the pseudo name absolute
  against the current directory, which for the extractor is the source root, so it would
  appear as a file *inside the project*. It needs a fixed pseudo path outside any source
  root (the prototype used `/__codeql_ada_predefined__/standard.ads`) and its text written
  to the source archive directly, since there is no file to copy.
- **It contains Libadalang-internal declarations**: `Universal_Int_Type_`,
  `Universal_Real_Type_`, `root_integer`, and `SyntheticSubpDecl`s for predefined
  operators (empty text). Literals are typed with these. Harmless for `float-equality`
  (`Universal_Real_Type_ is digits 16` is a `FloatingPointDef`, which is the right answer)
  but any query listing declarations must not treat them as user code.

### 1.5 Only *direct* targets are affordable

A unit is a direct target when some xref / expr-type / generic-instantiation / body-part
row from project code points into it. Extracting a unit means walking it, whose own
names point further out; the transitive closure is prohibitive:

| Project | Direct units | Direct nodes | Transitive units | Transitive nodes |
| --- | --- | --- | --- | --- |
| adasat (GPR) | 9 | +86.8% | 116 | +1666% |
| libkeccak (auto + runtime) | 31 | +36.9% | 259 | +298.6% |
| alire (prototype, auto + runtime) | 68 | +25.8% | — | — |

adasat's percentage is mostly `Standard`'s fixed 1,800 nodes against a 9,600-node
project; it falls as projects grow.

### 1.6 Cost of the prototype

| Project | Extraction, today → prototype | Database size |
| --- | --- | --- |
| libkeccak (159 files) | 6.7s → 21.5s | 8.4 MB → 9.6 MB |
| adasat (24 files) | 1.8s → 8.2s | 6.7 MB → 7.3 MB |
| alire (479 files) | 20.2s → 73.4s | 13 MB → 15 MB |

Most of the increase is 8.12a, not 8.12b: resolution that used to fail fast now does the
real work (alire pass 2, extracting 68 runtime units serially, was 23s of the 73s).
Pass 2 was not parallelised in the prototype; the real one should be.

### 1.7 Semantic sources and sinks for Phase 9 work

With the runtime visible, `Ada.Command_Line.Argument` resolves to its `SubpDecl` in
`a-comlin.ads`, and `GNAT.OS_Lib.Spawn` resolves *through the renaming*
`GNAT.OS_Lib renames System.OS_Lib` to `System.OS_Lib.Spawn` in `s-os_lib.ads`. A
semantic sink therefore catches both spellings, which a textual matcher on
`GNAT.OS_Lib.Spawn` would not. This is the reason to do 8.12b before Task 9.5.

### 1.8 No query results inside runtime files — yet

Across the fixture, libkeccak, adasat and alire, no query reported anything in a
predefined or runtime file. That is luck, not design: runtime specs contain
`pragma Warnings (Off)`, `SPARK_Mode (Off)` and comments, and nothing currently stops
`warnings-off` or `todo-comment` firing there. 8.12b needs an explicit filter (§3.2).

---

## 2. What changes for users

8.12a changes results substantially on every auto-provider project: several hundred
fewer false positives per project, a handful of new true positives, and — without the
§1.3 fixes — a handful of new false positives. That is a release-notes item in its own
right, and `scripts/corpus_baseline.json` must be refreshed in the same commit
(`nameres_errors` drops sharply, `xref`/`types` roughly double, extraction time roughly
triples).

---

## 3. Plan

### 3.1 Task 8.12a — make the runtime visible to the auto provider

1. **Runtime discovery** in `extractor.py`, in order: `CODEQL_EXTRACTOR_ADA_RUNTIME`
   (explicit directory); else `gcc -print-file-name=adainclude` if it names an existing
   directory; else none. Add its `*.ads` to the auto provider's `input_files` only; they
   are made resolvable, not extracted. The GPR path is left alone (it already finds the
   runtime).
2. **If no runtime is found**, emit one warning-severity diagnostic saying resolution
   will be degraded and how to set the variable. Silence here is how this went unnoticed.
3. **Fix the §1.3 query bugs** in `SelfComparison.ql` and `IdenticalOperands.ql`: compare
   dotted names component-wise (prefix and selector both), and narrow simple names to the
   defining name as D-024 does. Add test cases for `L.X = R.X` and `A, B : T; ... A = B`.
4. **Triage the 6 new `direct-recursion` results** and fix or document.
5. **Refresh `corpus_baseline.json`**, and record the before/after result counts in the
   commit message.
6. CI and release already install `gnat` via apt (`.github/workflows/*.yml`), so
   discovery works there with no workflow change. Confirm on the first CI run.

Acceptance: libkeccak `nameres_errors` falls roughly fivefold; the 322 libkeccak
results listed as lost in §1.2 stay lost; the new query tests pass; full suite green.

### 3.2 Task 8.12b — extract `Standard` and direct targets as pseudo-sources

1. **Two passes.** Pass 1 (existing, parallel) emits semantic rows for *any* resolved
   target and returns the set of out-of-source units they land in. Pass 2 extracts
   exactly those units, in parallel, with semantic rows limited to targets in the
   project or the pass-2 set, so there is no transitive closure (§1.5).
2. **`Standard` path**: fixed pseudo path outside any source root; archive its
   `unit.text`. Apply the mapping in `node_key` so references from project files and
   the unit's own nodes agree.
3. **Mark pseudo-source files.** A new `ada_predefined_file(@file)` table (dbscheme
   change; per D-011 no upgrade script pre-1.0), exposed as `File.isPredefined()` and an
   `AdaNode.fromSource()` helper in `ada.qll`. Every query in `ql/src` gets
   `fromSource()` on its reported element. Test: a fixture whose runtime dependency
   contains `pragma Warnings (Off)` must produce no `warnings-off` result there.
4. **Re-audit the D-015 list.** `float-equality` drops its limitation comment and gains a
   plain-`Float` test. `self-comparison` / `identical-operands` drop theirs.
   `unused-with-clause` now sees runtime packages (new true positives expected; re-check
   renamings such as `GNAT.OS_Lib`). The four textual matchers (`unchecked-conversion`,
   `unchecked-deallocation`, `raise-predefined-exception`, `boolean-literal-comparison`)
   become candidates for semantic rewrites; do each only with a test that the rewrite
   doesn't lose a case the textual form caught.
5. **Check the Phase 9 layers**: runtime package specs with initialised objects become
   CFG scopes and SSA source variables. Confirm the SSA conformance suite is unchanged,
   and that `PrintSsa` over a runtime-heavy fixture doesn't blow up.
6. **Decision record D-026** in `DECISIONS.md`, superseding D-015's "must match
   textually" rule: predefined and runtime entities are extracted as marked
   pseudo-sources, direct targets only; queries report only `fromSource()` elements.
7. Update Task 9.5 in `docs/phase9.2-plan.md`: sources and sinks match semantically
   (§1.7).

### 3.3 Order

8.12a first. It is small, fixes real false positives in shipped queries, and has no
dependency on 8.12b. 8.12b next, before Task 9.5, so 9.5 is written against semantic
sources and sinks. Neither blocks Tasks 9.3 or 9.4, so 8.12b and 9.3 can go in either
order.
