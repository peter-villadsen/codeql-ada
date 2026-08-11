# Decision log

## D-001 (2026-07-02) — Open-source model, MIT license
The CodeQL CLI's proprietary terms prohibit redistributing/bundling it or offering it as a
hosted service, and the free CLI terms only cover testing OSI-licensed queries. MIT-licensing
the extractor and packs keeps development and all users compliant, and matches the
`github/codeql` ecosystem. Monetization, if any, is services around the tool, not the tool.

## D-002 (2026-07-02) — Extractor prototype in Python
Libadalang's Python API (Python 3.11+) is the fastest path to a working extractor and exposes
Langkit introspection needed for generation (D-004). Revisit Python-vs-Ada for production
after measuring extraction throughput on a large corpus (burndown 1.5).

## D-003 (2026-07-02) — Build-less extraction
Libadalang resolves Ada semantics from GPR project files without running a compiler, so the
extractor uses `build_modes: [none]` and skips CodeQL's compiler-tracing machinery.
Discovery order: explicit GPR (env var) → single GPR found in tree → auto unit provider over
all `.ads`/`.adb` files.

## D-004 (2026-07-02) — Generate dbscheme, TRAP emitter, and QL AST classes
Generated from Libadalang/Langkit node-kind introspection (~400 kinds), following the pattern
of the Ruby and QL-for-QL extractors (generated from tree-sitter grammars). Hand-written code
is limited to the generator itself, core relations (files/locations/diagnostics), semantic
relations, and a QL convenience layer on top of the generated classes.

## D-005 (2026-07-02) — v1 semantic cut line
Stored in the database: full AST, tokens/comments, xref (ref → decl), expression types,
generic instantiation links. Not in v1: control flow graph and dataflow (built later in QL,
per burndown phases 4.3/4.4).

## D-006 (2026-07-02) — Scope: Ada 2012/2022, GPR-first
Target Ada 2012 and 2022 (whatever Libadalang parses); SPARK is just Ada to the extractor.
GPR-based projects are the primary target; bare source trees supported via auto provider.
Test corpus drawn from Alire crates.

## D-007 (2026-07-02) — Names
Language id `ada`; extension `.ads`/`.adb`/`.ada`. QL packs: `ada-all` (library) and
`ada-queries`, under a scope to be finalized before first `codeql pack publish`
(placeholder: `codeql-ada/`).

## D-008 (2026-07-02) — Dev environment
Primary dev on Windows where possible; Libadalang install on native Windows is expected to be
awkward, so WSL Ubuntu (already installed) is the fallback for anything Libadalang-touching.
CodeQL CLI pinned at v2.25.6 (installed at `C:\Users\peter\tools\codeql`).

## D-009 (2026-07-03) — Pack scope `peter-villadsen/`
Finalizes the D-007 placeholder. GHCR publishing via `codeql pack publish` requires the pack
scope to match a GitHub account the publisher controls; using the repo owner's scope lets the
in-repo `GITHUB_TOKEN` publish with no extra secrets (same pattern as
`advanced-security/codeql-extractor-iac`). Packs: `peter-villadsen/ada-all`,
`peter-villadsen/ada-queries`. The repo name stays `codeql-ada`. Can migrate to an org scope
later if the project grows — pre-1.0, with no external users, a rename is cheap.

## D-010 (2026-07-03) — v1 release artifact: Linux x86_64 only, Libadalang bundled
One release tarball, `codeql-extractor-ada-linux64.tar.gz`, built in the same Debian 13
container as CI (the only environment the extractor is verified on). It bundles the Libadalang
runtime — shared-library closure (incl. GNAT runtime libs, GPLv3 + GCC Runtime Library
Exception) and the ctypes-based Python bindings — with third-party license notices;
Libadalang itself is Apache-2.0, so redistribution is fine with attribution. Target machines
need only a system Python ≥ 3.11 and their own CodeQL CLI. Windows users run the Linux
tarball under WSL (documented); native Windows and macOS are deferred post-v1.

## D-011 (2026-07-03) — Tag-driven releases, one shared version, no pre-1.0 DB upgrades
The extractor pack (`codeql-extractor.yml`) and both QL packs carry the same version; a
`v<version>` git tag triggers a release workflow that verifies the tag matches the manifests,
runs the test suite, builds the tarball, attaches it to a GitHub Release, and publishes both
QL packs to GHCR. Pre-1.0 there are no dbscheme upgrade/downgrade scripts: a new release means
databases are re-created, and this is documented policy (closes burndown 2.4).

## D-012 (2026-07-03) — Pin Libadalang/Langkit commits; support one CodeQL CLI version
`scripts/build-libadalang.sh` moves from `master` branches to pinned commits for every
unversioned dependency it clones, so release builds are reproducible and corpus-regression
nameres numbers stop drifting. Supported CodeQL CLI = the pinned, tested version (currently
2.25.6). Bumping either pin is a deliberate change: update the pin, let CI rebuild (the cache
key hashes the build script), re-baseline the corpus if needed, and note it in the changelog.

## D-013 (2026-07-03) — CFG built in QL via the shared `codeql/controlflow` pack
The control flow graph is computed in QL (no dbscheme or extractor changes), by instantiating
the shared `codeql/controlflow` pack from `github/codeql` — the same framework Ruby, Swift,
C# and Rust use. The CFG is expression-level (every evaluated AST node is a CFG node, in
evaluation order), because (a) that is the shared framework's natural model, and (b) queries
of the form "a call to X is not always followed by a call to Y" need *call* nodes, not just
statement nodes. Exception edges use a conservative model: any call and any explicit raise
may transfer control to an applicable handler or out of the scope. Tasking constructs
(`select`, `accept`, `delay`, `abort`) are sequenced opaquely — no inter-task edges.
Fallback (only if the shared pack proves incompatible with CLI 2.25.6 or our Raw layer):
hand-roll a minimal CFG library exposing the same surface (entry/exit/successor/basic blocks);
record that as an amendment here before doing it.

## D-014 (2026-07-03) — Query growth: port rule *ideas*, not query code
QL query code is not portable across languages — every query is written against
language-specific AST classes and a language-specific dbscheme, so "porting the C# queries"
means re-implementing each rule's idea against the Ada library. Priority of source material:
(1) GNATcheck's rule catalog and the AdaCore Quality & Style guide — these speak the Ada
audience's language and map 1:1 onto Ada constructs; (2) CodeQL's C/C++ quality suite
(closest domain: systems code, manual memory, no GC); (3) C#'s *quality* queries where
language-agnostic. C#'s big query count comes overwhelmingly from taint-tracking security
queries plus .NET framework models — those become portable only after Phase 9 (dataflow),
not before, and the framework-specific ones (ASP.NET, LINQ, async) never apply.
Growth is organized in waves keyed to infrastructure: Wave A needs only AST+xref+types
(available today), Wave B needs the CFG (Phase 7), Wave C needs dataflow (Phase 9).

## D-015 (2026-07-03) — Semantic relations are source-set-relative; query authors must not rely on resolving out-of-source entities
All three semantic relations (`ada_xref`, `ada_expr_type`, `ada_generic_instantiation`) are
emitted only when the resolved declaration is itself in the analyzed source set
(`extractor.py`, `in_sources` guard). Anything declared in package `Standard` (`Float`,
`Boolean`, `Constraint_Error`, ...) or in library units outside the source set (the GNAT
runtime, external Alire crates) therefore never appears on the right-hand side of these
relations. Consequences, audited across all 22 queries on 2026-07-03:
- Type-based queries only see *user-declared* types — `float-equality` misses plain
  `Standard.Float` comparisons (documented in the query; found experimentally in Phase 8).
- Queries targeting language- or runtime-defined entities must match **textually**, never
  semantically — `unchecked-conversion`, `unchecked-deallocation`,
  `raise-predefined-exception`, and `boolean-literal-comparison` already do this and are
  unaffected; a semantic rewrite of any of them would silently go blind.
- Reference-identity queries (`self-comparison`, `identical-operands`) miss the edge where
  the compared name is declared out-of-source (documented in the queries).
- `unused-with-clause` deliberately only reports units whose declaration is in-source.
The durable fix is to extract `Standard` (and possibly the runtime spec closure) as
pseudo-sources so semantic rows exist for predefined entities; that is an extractor/dbscheme
workload, deferred — tracked as burndown item 8.12; re-audit the textual matchers above
for conversion once it lands.

## D-016 (2026-08-10) — CFG coverage is exhaustive over the grammar and enforced
Every one of the 405 node kinds in `schema/lal-nodes.json` carries an explicit verdict for
how the CFG treats it (`scope`, `shaped`, `expression`, `opaque`, `structural`, `n/a`),
published as the coverage appendix of `docs/cfg-design.md`. The verdicts are *derived from*
`ControlFlowGraphImpl.qll` by `scripts/check_cfg_coverage.py` rather than maintained by
hand, so the document cannot drift from the code; CI fails if a node kind is unaccounted
for or the appendix is stale. The point is that a future grammar addition cannot silently
slip past the CFG.

## D-017 (2026-08-10) — CFG conformance tests use inline expectations, not learned output
Expected CFG edges are written as `-- $ edge=...` comments in the `.adb` under test and
checked by `codeql.util.test.InlineExpectationsTest`; those tests' `.expected` files are
empty. `codeql test run --learn` records whatever the implementation does, including its
bugs, so a golden file cannot detect a wrong edge — an inline expectation has to be written
down by a human first. The check is exhaustive both ways: an unannotated edge fails, and an
annotation with no edge fails. `codeql/util` arrives transitively via `codeql/controlflow`,
so this added no dependency.

## D-018 (2026-08-10) — `docs/cfg-design.md` is the CFG specification
The document was rewritten from a prose mapping table into a per-construct specification:
each construct gets an Ada snippet, the exact edges it produces, and a link to the
conformance test enforcing them. It keeps its filename so existing references stay valid.
It is the rule; the tests are the enforcement. Change the spec first, then the test.

## D-019 (2026-08-10) — Known imprecisions are expectations, not prose
A deliberate or accepted CFG imprecision is recorded as a `$ MISSING:` expectation (and, if
an edge must disappear, `$ SPURIOUS:`) in the relevant conformance test, not as a sentence
in a document. The framework then reports "Fixed missing result" on the day someone fixes
it. This is not theoretical: all four defects found in Phase 7.7 were pinned this way
first, and each fix reported exactly the predicted edges at the predicted positions.

## D-020 (2026-08-10) — Positioning: complement CodeQL estates, do not displace GNATcheck
An assessment, recorded because it should govern what gets built next.

**The finding.** AdaCore's GNATcheck is a mature, vendor-backed Ada rule checker with
**211 predefined rules** (plus 120 GNATkp known-problem rules), implemented in LKQL over
**the same Libadalang frontend this project uses**. We ship 24 rules. Consequences:

- **No fidelity advantage is available.** Same parser, same name resolution. We are in fact
  behind, because extraction loses information that GNATcheck queries directly — see D-015
  and burndown 8.12.
- **No certification story.** AdaCore sells qualification material for the DO-178C /
  EN 50128 regimes this audience works under. A community extractor has none.
- **Rule-count parity is unreachable** and would produce a worse GNATcheck.

**What GNATcheck does not do.** Checked against all 211 rule names on 2026-08-10: zero
matches for taint, inject, sql, command, sanitize, source or sink. It is a coding-standards
checker, not a security dataflow engine. Note this does *not* mean AdaCore lacks deep
analysis — GNAT SAS/CodePeer (abstract interpretation) and SPARK (proof) occupy that space,
and are the real comparators for anything beyond syntax.

**Decision.** Do not position or grow this project as a GNATcheck replacement. The only
defensible audience is an organisation **already running CodeQL across other languages**
that wants its Ada to stop being a hole in the same security posture, triage workflow and
compliance reporting — plus interprocedural taint analysis, which Ada tooling does not
offer. Note honestly that this audience is small.

**Consequences.**
- Revises the emphasis of D-014: GNATcheck's catalog is a **cross-check** for the rules we
  already have, not a backlog to work through. Adding syntactic rules competes where we are
  weakest.
- The differentiated value is Phase 9 (SSA → dataflow → taint) plus platform integration
  (Phase 10). Everything else is table stakes.
- **Open and undecided:** whether that audience justifies Phase 9's cost. This decision
  does not settle it, and the project is at a natural stopping point either way.
