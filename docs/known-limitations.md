# Known limitations

codeql-ada is pre-1.0. This page lists what to expect before you try it on your
own code, and what is worth reporting. The details are in the
[user guide](user-guide.md#known-limitations) and in
[dataflow-design.md](dataflow-design.md), "Named v1 limitations".

## Platform

- **Linux x86_64 only**, with glibc 2.38 or newer (Ubuntu 24.04, Debian 13). On Windows, use WSL.
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

## What data flow follows, and where it is approximate

Data flow follows a value from where it is produced to where it is used, across
subprogram calls: ordinary calls, calls to generic instances, dispatching calls (into
every override), calls through access-to-subprogram values, and task and protected entry
calls. It follows values through record components, array elements, standard
containers, package variables, and variables shared with nested subprograms.

Where it is approximate, the cost depends on the kind of query:

- **Queries that look for a flow** (taint queries such as `ada/command-line-injection`)
  can **miss** a flow through a gap, or **report** one that an approximation allows but
  the program never takes.
- **Queries that must prove something happened** (a file is closed, storage is freed)
  **report a false alarm** when the close or the free happens on the far side of a gap,
  and can **miss** a real problem when an approximation counts a free that never
  happens on that path.

The approximations:

- **Elements and keys.** All elements of an array or container count as one, so a value
  stored at one index is seen at every index; map keys are not told apart.
- **Aggregates.** A positional record aggregate (`(X, 0)` rather than `(A => X, B => 0)`)
  does not record which component gets which value.
- **Containers.** Only `Ada.Containers` (vectors, lists, maps, sets and their variants)
  is modelled, for the common operations (`Append`, `Insert`, `Include`, `Element`,
  cursors, `for ... of` loops). Other container libraries are not followed.
- **Shared variables ignore call order.** A value stored in a package variable, or in a
  variable of an enclosing subprogram, by any subprogram reaches reads of it in every
  other subprogram, including reads that run before the store.
- **Dispatching** goes to every override of the called operation, whatever the actual
  object is. Overriding is worked out from names and parameter counts within a tagged
  type hierarchy; interfaces are not covered.
- **Access-to-subprogram values** held in a record component reach every call through
  that component, whatever the object.
- **Entries.** Values passed into an `accept` statement or entry body are followed;
  values passed back through an entry's `out` formals are not.
- **Generic formal subprograms.** A call inside a generic body to one of its formal
  subprograms (`with procedure Process (X : T);`) is not resolved.

The control-flow graph runs a GNAT `finally` part however its sequence is left, but does
not split it: after the `finally` part, control may continue any way the part was
entered, so a path entering by `return` may also continue as if the sequence had completed
normally. It evaluates a quantified expression's predicate once, standing for every
iteration, and does not tell `case` alternatives apart by value: every alternative is
reachable. The Guards library does not find a `case` alternative with more than one
choice (`when 2 | 3`) to control its statements, and knows integer ranges only from a
comparison with a decimal literal.

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
