# Writing queries

This is a guide to adding your own query to this project (or forking it to
build a private one). It assumes you've read the
[user guide](user-guide.md) and know what a database and a QL pack are; it
does not assume prior QL experience.

## The two packs

QL code here is split across two packs — the same "pack" concept as a
language's package registry entry, just for QL:

- **`ql/lib`, published as `peter-villadsen/ada-all`** — the library. No
  queries live here, only reusable QL classes that queries import.
- **`ql/src`, published as `peter-villadsen/ada-queries`** — the 11 shipped
  queries, each a standalone `.ql` file under `ql/src/queries/`. This pack
  depends on `ada-all`.

There's a third pack, `ql/test` (`ada-tests`), holding every query's test
fixtures. It's never published — it exists purely for `codeql test run`
(see [Testing a query](#testing-a-query) below).

## The two API layers

Every query starts with `import ada`, which pulls in `ql/lib/ada.qll`. That
file re-exports two layers, and knowing which one you're using matters:

**The generated layer, `Raw::`** (`ql/lib/codeql/ada/ast/internal/Raw.qll`,
~2,300 lines and counting) mirrors Libadalang's node hierarchy one class per
node kind (405 node kinds as of the last introspection dump, see
[BURNDOWN.md](../BURNDOWN.md) Phase 1.3) — `Raw::ExceptionHandler`,
`Raw::PragmaNode`, `Raw::GenericSubpInstantiation`, and so on, all the way
down. It's generated from Libadalang's own introspection data
(`generator/gen.py`, see [CONTRIBUTING.md](../CONTRIBUTING.md) if you need to
regenerate it) and you should never need to edit it by hand. If you know the
Ada construct you're after, its QL class name is almost always the obvious
CamelCase version of its Libadalang kind name; when in doubt,
[docs/dbscheme-conventions.md](dbscheme-conventions.md) documents the naming
rules precisely, and Libadalang's own
[GitHub repository](https://github.com/AdaCore/libadalang) documents what
each kind means in Ada terms.

**The hand-written layer** (`ql/lib/ada.qll`, unqualified class names) adds
the conveniences a generated 1:1 mirror can't provide on its own:

| Class / member | What it gives you |
|---|---|
| `Name.getText()` | Reconstructed source text of a name (handles simple identifiers, string/char literals used as names, and dotted names like `A.B.C` recursively) |
| `Name.getReferencedDecl()` | The declaration a name resolves to, if extraction resolved it (backed by the `ada_xref` relation — see the user guide's note on name-resolution quality) |
| `Expr.getType()` | The expression's type declaration, if extraction resolved it (`ada_expr_type`) |
| `BasicDecl.getADefiningName()` / `getAName()` | The name(s) a declaration introduces, and their text |
| `BasicDecl.isReferenced()` | Whether any resolved name anywhere points back at this declaration — the basis for `UnusedVariable.ql` |
| `AdaNode.getEnclosingSubprogram()` / `getEnclosingUnit()` | Walk outward to the innermost subprogram body / the containing compilation unit |
| `Comment` (`Raw::Comment`) | Source comments — these are token trivia in Libadalang, not AST nodes, so they're a separate hand-written relation (`ada_comments`), not part of the `Raw::` node tree |

Reach for the hand-written layer first; drop to `Raw::` for anything it
doesn't cover, which in practice is most of the actual query logic — the
hand layer is deliberately small.

## Query metadata and `@kind`

Every query needs a metadata block identifying it to the CLI:

```ql
/**
 * @name Short human-readable name
 * @description One or two sentences: what this flags and why it matters.
 * @id ada/your-query-id
 * @kind problem
 * @problem.severity warning
 * @tags reliability security
 */
```

Use `@kind problem` with a `select node, "message"` shape (one flagged
element, one message string) unless you have a specific reason not to — this
is what makes `codeql database analyze` able to render results as SARIF
alerts with a location and a message, which is how every downstream
consumer (GitHub code scanning, editor integrations, `sarif-latest` output)
expects results to look. `@problem.severity` is `error`, `warning`, or
`recommendation` — roughly: certainly-a-bug, worth-a-look, and
style/maintainability respectively; see the 11 shipped queries for examples
of each. `@kind table` (arbitrary tuples, no location/message shape) exists
for exploratory or diagnostic queries, but such a query can't be interpreted
by `database analyze` — only run directly (`codeql query run`) or by
`codeql test run` in a test fixture.

## Adding a query

1. Write `ql/src/queries/YourQuery.ql`. The 11 existing queries in that
   directory are templates — `UnusedVariable.ql` and `TodoComment.ql` are
   good starting points if your query is a single `from`/`where`/`select`
   over one node type; `HardcodedCredential.ql` shows a multi-variable
   `from` with a name-pattern heuristic; `SelfComparison.ql` and
   `UnusedWithClause.ql` show comparing/joining on a resolved declaration
   (`getReferencedDecl()`) rather than matching on node kind alone;
   `UnreachableStatement.ql` shows sibling-position reasoning within a
   statement list (`getChild(i)`/`getChild(i + 1)`) without needing a CFG.
   Whatever you report, add `x.(AdaNode).fromSource()` (or
   `c.(Comment).fromSource()`) so nothing is reported inside a predefined
   pseudo-source (D-026).
2. Add a test: create `ql/test/queries/YourQuery/` containing
   `YourQuery.qlref` (one line: `queries/YourQuery.ql`) and one or more Ada
   source snippets exercising both a case that should be flagged and one
   that shouldn't.
3. Bootstrap the expected output rather than writing it by hand:
   ```sh
   codeql test run ql/test/queries/YourQuery --additional-packs=ql --search-path=extractors
   ```
   With no `.expected` file yet, this fails and prints a diff against an
   (absent) empty expectation — that diff *is* your query's actual output.
   Read it over to confirm it's what you intended, then accept it:
   ```sh
   codeql test accept ql/test/queries/YourQuery/YourQuery.qlref
   ```
   This renames the `.actual` file `codeql test run` left behind to
   `.expected`. Re-run the same `codeql test run` command to confirm it now
   passes — that's your regression test from now on. `codeql test run
   --learn` is an equivalent shortcut for the same bootstrap-then-review
   workflow (it writes `.expected` directly instead of leaving a `.actual`
   file for `codeql test accept` to rename); either works on the CLI version
   this project targets. Either way, **review the diff before trusting it**
   — both mechanisms record whatever the query actually does, bugs
   included.
4. Run the full suite before committing:
   ```sh
   codeql test run ql/test --additional-packs=ql --search-path=extractors
   ```

## Finding a call not invariably followed by another (`MissingPairedCall`)

If your rule idea is shaped like "a call to `Foo` should always be followed
by a call to `Bar` before control leaves the enclosing subprogram" (resource
acquire/release pairs: open/close, seize/release, lock/unlock, ...), you
don't need to hand-write a control-flow search — instantiate
`MissingPairedCall` from `codeql/ada/controlflow/PairedCalls.qll`, built on
the Ada CFG. [cfg-design.md](cfg-design.md) specifies the CFG construct by
construct — each section gives an Ada snippet, the exact edges it produces and
a link to the conformance test that enforces them, so you can predict what
your query will see before running it. `OpenWithoutClose.ql` is the worked example this module was
built for; read it alongside this section.

```ql
import ada
import codeql.ada.controlflow.Cfg
import codeql.ada.controlflow.PairedCalls

private predicate isFoo(Raw::AdaNode call) { /* your match on `Foo` calls */ }

private predicate isBar(Raw::AdaNode call) { /* your match on `Bar` calls */ }

module FooBar = MissingPairedCall<isFoo/1, isBar/1>;

from Raw::AdaNode call
where FooBar::missingPairedCallNormalPathsOnly(call)
select call, "This Foo is not invariably followed by a Bar."
```

A few things worth knowing before you instantiate it:

- **`isFoo`/`isBar` match call *sites*, by call kind, not specific objects.**
  If your program can open two different files and only close one, this
  module won't tell you *which* file leaked — it pairs by "a call matching
  `isBar` occurred somewhere reachable", not "the same object's close was
  called". Document this limitation in your query the way
  `OpenWithoutClose.ql` does, rather than trying to fix it here — proper
  per-object pairing needs dataflow (Phase 9), not just a CFG.
- **Two variants, different signal-to-noise.** Use
  `missingPairedCallNormalPathsOnly` (ignores exceptional/raise edges) as
  your default — a path that only reaches the scope exit by first raising an
  exception is usually not what you mean by "leaked". Use
  `missingPairedCallStrict` if you want every path considered, including
  ones that only escape via an unhandled exception.
- **Resolving what a call "is" is the hard part, not the CFG part.** Package
  `Standard` and the runtime units a project refers to directly are extracted
  as predefined pseudo-sources (D-026), so `getReferencedDecl()` on a call to
  `Ada.Text_IO.Open` gives its `SubpDecl` in `a-textio.ads`, whether it was
  spelled in full or through a `use` clause or package renaming. Identify it
  with `BasicDecl.hasQualifiedName("Ada.Text_IO.Open")` (case-insensitive;
  Libadalang's fully qualified name, extracted for every declaration), and
  call `getUltimateDecl()` first to see through subprogram, object, exception
  and package renamings (`GenericInstantiation.getDesignatedGeneric()` already
  sees through generic renamings). Runtime units resolve only if a GNAT
  runtime was found at extraction (see the user guide); `Standard` always
  does. The pattern the shipped queries use (`isTextIoOp` in
  `OpenWithoutClose.ql`, `UncheckedConversion.ql`, ...) is: match
  semantically, and fall back to the name's text only when it does not
  resolve at all. Test it with a case only the semantic match catches (a
  renaming), so the test fails if resolution stops working.
- **Report only project code.** Every query restricts its reported element
  with `fromSource()` (on `AdaNode` and `Comment`), so nothing is reported
  inside a predefined file (D-026).

## Data flow and taint tracking

To ask "can this value reach that call?", import `codeql.ada.dataflow.DataFlow` and
`codeql.ada.dataflow.TaintTracking`. Then write a module implementing
`DataFlow::ConfigSig` (`isSource`, `isSink`, and optionally `isBarrier`) and instantiate
`TaintTracking::Global<Config>`. Use `DataFlow::Global<Config>` instead when only an
unchanged value counts. Flow crosses subprogram boundaries.

**"No tainted value may reach this subprogram."** Make every argument of a call to it a
sink:

```ql
/**
 * @name Untrusted data reaches My_App.Db.Execute
 * @kind path-problem
 * @id my-app/untrusted-to-execute
 * @problem.severity error
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking
import codeql.ada.security.CommandInjection

module Config implements DataFlow::ConfigSig {
  // What counts as tainted: here the command line (the built-in source), and the
  // inputs of a request handler.
  predicate isSource(DataFlow::Node n) {
    n instanceof CommandInjection::Source or
    DataFlow::isParameterOf(n, "My_App.Server.Handle_Request")
  }

  // Every argument of every call to My_App.Db.Execute ...
  predicate isSink(DataFlow::Node n) {
    exists(Raw::Expr call | DataFlow::isCallTo(call, "My_App.Db.Execute") |
      n.asExpr() = DataFlow::getAnArgument(call)
    )
  }
  // ... or only one formal of it:
  //   DataFlow::isArgumentFor(call, n.asExpr(), "Query")

  // Values that passed a validator are clean.
  predicate isBarrier(DataFlow::Node n) {
    exists(Raw::Expr call | DataFlow::isCallTo(call, "My_App.Validate.Sanitize") |
      n.asExpr() = call
    )
  }
}

module Flow = TaintTracking::Global<Config>;

import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink) and sink.getNode().asExpr().(AdaNode).fromSource()
select sink.getNode(), source, sink, "This argument depends on $@.", source.getNode(),
  "untrusted data"
```

The helpers resolve by meaning, not text, so `use` clauses and renamings are covered and
every overload of the name matches. Names are the fully qualified ones Libadalang computes:
a subprogram nested in another is `Outer.Inner`. The full list is in
[dataflow-design.md](dataflow-design.md), "Taint tracking".

**Adding to the built-in command-injection query instead.** If the subprogram runs a
command, extend `CommandInjection::Sink` in a `.qll` file. Then write a copy of
`CommandLineInjection.ql` that imports that file as well. A subclass takes effect only in
queries that import it.

```ql
class MyShellSink extends CommandInjection::Sink {
  MyShellSink() {
    exists(Raw::Expr call |
      DataFlow::isCallTo(call, "My_App.Shell.Run") and
      DataFlow::isArgumentFor(call, this.asExpr(), "Command")
    )
  }
}
```

`CommandInjection::Source` and `CommandInjection::Barrier` extend the same way.
`ql/test/library/TaintTracking` is a small working example of the first pattern. Its
test should route the value through at least one other subprogram, so it fails if
cross-procedure flow breaks. What is and is not followed is listed in
[dataflow-design.md](dataflow-design.md), "Named v1 limitations" and "Taint tracking".

## Testing a query

The pattern above — `.qlref` pointing at the real query, plus fixtures, plus
`.expected` — is how all 11 shipped queries are tested, and is what the
`ql/test` pack (`ada-tests`, depending on `ada-queries`, see
[The two packs](#the-two-packs)) exists for. `ql/test/extractor/` holds a
different kind of test: test-local `.ql` files with no `.qlref`,
used for golden-output checks on the extractor itself (e.g. `PrintAst.ql`
dumps every node's kind/parent/index to guard the extraction pipeline
independent of any specific query). You won't need this pattern for a normal
query addition — it's for changes to the extractor or generator.
