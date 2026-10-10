# Known limitations

codeql-ada is pre-1.0. This page lists what to expect before you try it on your
own code, and what is worth reporting. The details are in the
[user guide](user-guide.md#known-limitations) and in
[dataflow-design.md](dataflow-design.md), "Named v1 limitations".

## Platform

- **Linux x86_64 only** (glibc as new as Debian 13's or newer). On Windows, use WSL.
  Native macOS and Windows are not supported yet (D-010).
- The CodeQL CLI is not bundled. Install it yourself; 2.25.6 is the tested version.

## Databases may need rebuilding

The database format (the dbscheme) can change in any pre-1.0 release, and there is no
upgrade path (D-011). After upgrading the extractor or the packs, re-run
`codeql database create` instead of reusing an old database. A database built by an
older release may fail to load.

## Name resolution depends on your project file

Results are best when the extractor finds your GNAT project (`.gpr`) file. Without one,
it parses every `.ads`/`.adb` file in the tree, and references it cannot resolve are
missed by every query that depends on them. See
[Project discovery](user-guide.md#project-discovery-and-name-resolution-quality).
The build log's summary line tells you how many files had parse errors.

## What data flow does not follow

Taint-tracking queries (such as `ada/command-line-injection`), and queries that need
to *prove* something (that storage is freed, say), miss or mis-report flows through:

- dispatching calls (bound to their static target only),
- calls through access-to-subprogram values,
- calls to generic subprogram instances (`procedure P is new G (...)`, then `P (X)`),
- task entry calls,
- values stored in record components, array elements or containers,
- variables of enclosing subprograms or packages written by a nested subprogram.

The control-flow graph doesn't yet model GNAT `finally` parts, the message of
`raise ... with`, or quantified-expression iterators.

## Other modelling limits

- Generic instance bodies are not modelled as separate copies: an instantiation links
  to the generic it instantiates.
- Two AST nodes of the same kind at exactly the same source span collapse into one.
  This has not been seen in practice.

## What to report

[Open an issue](https://github.com/peter-villadsen/codeql-ada/issues/new/choose) for:

- an extractor crash, or a file that Libadalang parses but the extractor rejects,
- a **false positive**: a result that is wrong,
- a **false negative**: a result you expected but didn't get, unless it is caused by one
  of the limitations above,
- documentation that doesn't match what the tool does.

A small Ada snippet that reproduces the problem is the most useful thing you can
include.
