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
