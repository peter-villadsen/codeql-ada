# Writing queries

This is a guide to adding your own query to this project (or forking it to
build a private one). It assumes you've read the
[user guide](user-guide.md) and know what a database and a QL pack are; it
does not assume prior QL experience.

## Start here

If you have written CodeQL queries for Java, an Ada query reads the same way.
The parameters of a subprogram:

```ql
import ada

from Subprogram s, Parameter p
where s.hasQualifiedName("AdaSAT.Formulas.Free_All") and p = s.getAParameter()
select p, p.getName(), p.getMode(), p.getType()
```

Results: `F`, `F`, `in out`, `Formula`. The classes, against Java's:

| Java | Ada | Notes |
|---|---|---|
| `Callable`, `Method` | `Subprogram` | A procedure or function. One per subprogram, although Ada declares most of them twice (spec and body): see [The library](#the-library) |
| `Parameter` | `Parameter` | Each name of `A, B : in T` is one; `getMode()` is `"in"`, `"out"` or `"in out"` |
| `Call`, `MethodCall` | `Call` | With or without parentheses, operators, prefixed views (`Obj.Op (X)`), through renamings |
| `RefType`, `Class` | `Type`, `Package` | A package is the unit of declarations; a type does not contain subprograms |
| `Field` | `Component` | A record component |
| `LocalVariableDecl`, `Variable` | `Variable` | Objects, constants, object renamings, loop variables |
| `IfStmt`, `AddExpr`, ... | `IfStmt`, `BinOp`, ... | One class per Libadalang node kind (see [ast-reference.md](ast-reference.md)) |

Then, a path that works:

1. **Learn the language from GitHub's documentation.** The
   [QL tutorials](https://codeql.github.com/docs/writing-codeql-queries/ql-tutorials/)
   are small puzzles that teach predicates, classes, aggregates and
   recursion without any codebase. Keep the
   [QL language reference](https://codeql.github.com/docs/ql-language-reference/)
   open while you write. For running queries from the editor, see
   [CodeQL for VS Code](https://codeql.github.com/docs/codeql-for-visual-studio-code/).
2. **Learn what Ada turns into.** Read [ast-reference.md](ast-reference.md)
   for the common shapes and the traps, and look at your own code's tree
   (see [Seeing the tree](#seeing-the-tree) below).
3. **Read this guide**, then read shipped queries in order of difficulty:
   - `GotoStatement.ql`: one node kind.
   - `DirectRecursion.ql`: calls (`Call`).
   - `UnusedVariable.ql`: resolved declarations.
   - `UnreachableStatement.ql`: sibling positions.
   - `OpenWithoutClose.ql`: the control-flow graph.
   - `CommandLineInjection.ql`: taint tracking across subprograms.
4. **Write a test before trusting a query**
   (see [Testing a query](#testing-a-query) below).

## The packs

QL code here is split across packs — the same "pack" concept as a
language's package registry entry, just for QL:

- **`ql/lib`, published as `peter-villadsen/ada-all`** — the library: the
  classes queries import. It also holds two tools that are not analysis
  queries: `ide-contextual-queries/printAst.ql` (VS Code's "View AST") and
  `tools/PrintAst.ql` (the same tree as text). They live here rather than in
  `ql/src` so that `codeql database analyze ql/src` never picks them up.
- **`ql/src`, published as `peter-villadsen/ada-queries`** — the 25 shipped
  queries, each a standalone `.ql` file under `ql/src/queries/`. This pack
  depends on `ada-all`.

There's a third pack, `ql/test` (`ada-tests`), holding every query's test
fixtures. It's never published — it exists purely for `codeql test run`
(see [Testing a query](#testing-a-query) below).

## The library

Every query starts with `import ada`, which pulls in `ql/lib/ada.qll`. It gives
two kinds of class, both without a prefix.

**Semantic classes** (`codeql/ada/Subprograms.qll`, `Calls.qll`,
`Declarations.qll`) answer the usual questions directly:

| Class | Main predicates |
|---|---|
| `Subprogram` | `getName`, `hasName`, `hasQualifiedName`, `isGeneric`, `getAParameter`, `getParameter(i)`, `getNumberOfParameters`, `isFunction`, `isProcedure`, `getReturnType`, `getBody`, `getADeclaration`, `getACall` |
| `Parameter` | `getName`, `getMode`, `isIn`, `isOut`, `getType`, `getTypeExpr`, `getDefaultExpr`, `getIndex`, `getSubprogram`, `getAnAccess` |
| `Call` | `getTarget`, `getArgument(i)`, `getArgumentFor(Parameter)`, `getArgumentByName`, `getAnArgument`, `getCaller`, `isStatement` |
| `Type` | `getName`, `isRecord`, `isTagged`, `isEnumeration`, `isArray`, `isAccess`, `isPrivate`, `isSubtype`, `getParentType`, `getAComponent`, `getAnEnumerationLiteral` |
| `Component` | `getName`, `getType`, `getDeclaringType`, `getDefaultExpr`, `getAnAccess` |
| `Variable` | `getName`, `getType`, `getInitializer`, `isConstant`, `isRenaming`, `isLoopVariable`, `isLocal`, `getDeclaringSubprogram`, `getAnAccess` |
| `Package` | `getName`, `getBody`, `getAMember`, `getAPublicMember`, `getASubprogram`, `getAType`, `getAVariable`, `isGeneric`, `isGenericInstance`, `getGeneric` |

Two things differ from Java because Ada differs:

- **Declared twice, counted once.** A subprogram with a spec in the `.ads` and a
  body in the `.adb` is two AST nodes. `Subprogram` is the first of them (the
  spec when there is one), so `hasQualifiedName` finds one subprogram, not two.
  `getBody()` and `getADeclaration()` reach the others. Its parameters are the
  spec's; `Parameter.getAnAccess()` finds the uses in the body, which resolve to
  the body's copy.
- **What v1 does not cover.** A generic subprogram is a `Subprogram`
  (`isGeneric()`), but an instance of one (`procedure P is new G (...)`) is not,
  and calls to instances are not `Call`s. Dispatching calls bind to the static
  target, and calls through access-to-subprogram values do not resolve
  (`docs/dataflow-design.md`). A private type and its full declaration are two
  `Type`s.

**AST classes**, one per Libadalang node kind (`CallExpr`, `PragmaNode`,
`GenericSubpInstantiation`, ...), mirror the parse tree. They are generated from
Libadalang's own introspection data (`ql/lib/codeql/ada/ast/internal/Raw.qll`,
`generator/gen.py`; never edit it by hand), and also go by `Raw::X`, after the
module they are generated in. Each field of a node is an accessor named after
Libadalang's field (`f_suffix` becomes `getSuffix()`); list nodes have
`getChild(i)`; token nodes (identifiers, literals, operators) have `getValue()`.
[docs/dbscheme-conventions.md](dbscheme-conventions.md) documents the naming
rules. **Don't guess the shape from the names.** Several Ada constructs parse
differently from what you'd expect (a type conversion is a `CallExpr`, for
example). Read [ast-reference.md](ast-reference.md) and look at the tree.

Hand-written predicates on the AST classes (`codeql/ada/ast/internal/Extensions.qll`,
D-027) add what a 1:1 mirror can't:

| Class / member | What it gives you |
|---|---|
| `AdaNode.fromSource()`, `Comment.fromSource()` | Holds outside the predefined pseudo-sources (package `Standard`, the runtime specs). **Every query restricts what it reports with this** (D-026). |
| `Name.getText()` | Reconstructed source text of a name (handles simple identifiers, string/char literals used as names, and dotted names like `A.B.C` recursively) |
| `Name.getReferencedDecl()` | The declaration a name resolves to, if extraction resolved it (backed by the `ada_xref` relation; see the user guide's note on name-resolution quality) |
| `Name.denotesSameEntityAs(other)` | Two names denote the same entity, compared structurally (both prefix and selector of a dotted name) |
| `Expr.getType()` | The expression's `Type`, if extraction resolved it (`ada_expr_type`) |
| `BasicDecl.getQualifiedName()` / `hasQualifiedName("Ada.Text_IO.Open")` | Libadalang's fully qualified name; `has…` ignores case. The way to identify a runtime entity. |
| `BasicDecl.getUltimateDecl()` | Follows subprogram, object, exception and package renamings to what is renamed |
| `BasicDecl.getADefiningName()` / `getAName()` | The name(s) a declaration introduces, and their text |
| `BasicDecl.getCompletion()`, `BaseSubpBody.getDeclaration()` | A declaration's completion and back (`ada_body_part`, D-021) |
| `BasicDecl.isReferenced()` | Whether any resolved name anywhere points back at this declaration; the basis for `UnusedVariable.ql` |
| `GenericInstantiation.getDesignatedGeneric()` | The generic an instantiation designates, through generic renamings |
| `AdaNode.getEnclosingSubprogram()` / `getEnclosingUnit()` | Walk outward to an enclosing subprogram body / the containing compilation unit |
| `File.isPredefined()` | The file is a predefined pseudo-source |
| `Comment` | Source comments: token trivia in Libadalang, not AST nodes, so a separate hand-written relation (`ada_comments`), not part of the node tree |

Results show what a node is: a declaration by its name (`Free_All`), an
expression by a short rendering (`F.Length`, `Append (...)`, `... = ...`), a
statement by its leading keywords (`if ...`, `raise Constraint_Error`).
`getAPrimaryQlClass()` gives the class.

Reach for the semantic classes first, and the AST classes for the shape of the
code. Beyond these, `codeql.ada.controlflow.Cfg` gives the control-flow graph
(see `MissingPairedCall` below), and `codeql.ada.dataflow.DataFlow` /
`TaintTracking` give data flow (see
[Data flow and taint tracking](#data-flow-and-taint-tracking)).

## Seeing the tree

The quickest way to learn which classes and accessors to use is to look at
the tree the extractor builds for code like the code you want to match.

**In VS Code.** Open an Ada database in the CodeQL extension, open a source
file from it, and run **CodeQL: View AST**. The extension finds
`ide-contextual-queries/printAst.ql` in `ada-all` by its tag. Each node shows
its class, its token text, and what a name resolves to
(`Identifier Argument -> Ada.Command_Line.Argument`). Each edge shows the
accessor that reaches the child (`getSuffix`), or `[i]` for a list element.
GitHub's page on
[exploring the structure of your source code](https://codeql.github.com/docs/codeql-for-visual-studio-code/exploring-the-structure-of-your-source-code/)
describes the viewer. Step by step, on Windows with the toolchain in WSL:

1. Connect VS Code to the WSL distro that has the CodeQL CLI and the
   databases (**WSL: Connect to WSL using Distro...**). Extensions and
   remote settings are per distro.
2. Open this repository as the workspace folder (Windows drives are under
   `/mnt/c/...`); the extension finds `ada-all` among the workspace folders.
3. Install the CodeQL extension in that distro, and set
   `codeQL.cli.executablePath` (Remote settings tab) to the pinned CLI, so
   that the extension does not download a newer one.
4. **CodeQL: Choose Database from Folder** → the database directory.
5. In the Databases view, right-click the database → **Add Database Source
   to Workspace**, and open a file from the `[<db> source archive]` folder.
   This turns the window into an untitled multi-root workspace and reloads
   it, and the extension keeps its database list per workspace: if View AST
   then says "Can't infer database from the provided source", add the
   database again (and save the workspace to keep it).
6. Run **CodeQL: View AST** with that file active. The tree appears in the
   **AST Viewer** section of the CodeQL sidebar, usually collapsed at the
   bottom.

Known side effect: running View AST deletes `ql/lib/codeql-pack.lock.yml`
(the extension's log says "Deleting temporary package lock file"). Restore it
with `git checkout -- ql/lib/codeql-pack.lock.yml` before committing. While
VS Code has a database open, its query server locks it, and a command-line
query on the same database fails with "the cache directory is already
locked".

**From the command line.** Put the Ada you want to look at in a scratch
directory, build a small database from it, and print every project file's
tree as indented text:

```sh
mkdir -p /tmp/ast && cp snippet.adb /tmp/ast/
codeql database create /tmp/ast-db --language=ada --build-mode=none \
  --search-path=<dir containing ada/> --source-root=/tmp/ast
codeql query run --database=/tmp/ast-db --additional-packs=<repo>/ql \
  <repo>/ql/lib/tools/PrintAst.ql
```

Each output line is `accessor: Class token -> resolved declaration`, indented
by depth:

```
getCall: CallExpr -> Test.Sink
  getName: Identifier Sink -> Test.Sink
  getSuffix: AssocList
    [0]: ParamAssoc
      getRExpr: QualExpr -> Test.List
```

Read that as `call.(CallStmt).getCall().(CallExpr).getSuffix()...`.
The query prints every project file, so keep the scratch directory small.

**As text, JSON or XML, for chosen files.** `scripts/print_ast.py` prints the
same tree for any database, restricted to the files you name (by path
suffix), with each node's position:

```sh
python3 scripts/print_ast.py <db> --file adasat-formulas.adb             # indented text
python3 scripts/print_ast.py <db> --file adasat-formulas.adb --format json --out ast.json
python3 scripts/print_ast.py <db> --format xml --out ast.xml             # every file
```

In JSON each node is `{"edge", "class", "text", "resolvesTo", "start", "end",
"children"}`, leaving out the empty ones. In XML each node is an element named
by its class, with the rest as attributes:

```xml
<CallExpr edge="getCall" resolvesTo="Ada.Strings.Unbounded.Append" start="21:10" end="21:41">
  <Identifier edge="getName" text="Append" resolvesTo="Ada.Strings.Unbounded.Append" start="21:10" end="21:16" />
```

It runs `ql/lib/tools/PrintAstRows.ql` and rebuilds the tree from its rows.
`--copy-db` runs on a temporary copy, for a database VS Code has open.

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
style/maintainability respectively; see the shipped queries for examples
of each. `@kind table` (arbitrary tuples, no location/message shape) exists
for exploratory or diagnostic queries, but such a query can't be interpreted
by `database analyze` — only run directly (`codeql query run`) or by
`codeql test run` in a test fixture. Use `@kind path-problem` when the result is a
flow from a source to a sink and the path should be shown (`select sink,
source, sink, "message"`, with `import Flow::PathGraph`; see
[Data flow and taint tracking](#data-flow-and-taint-tracking) and GitHub's
[creating path queries](https://codeql.github.com/docs/writing-codeql-queries/creating-path-queries/)).
The full set of metadata properties is in GitHub's
[metadata reference](https://codeql.github.com/docs/writing-codeql-queries/metadata-for-codeql-queries/).

## Adding a query

1. Write `ql/src/queries/YourQuery.ql`. The existing queries in that
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

private predicate isFoo(AdaNode call) { /* your match on `Foo` calls */ }

private predicate isBar(AdaNode call) { /* your match on `Bar` calls */ }

module FooBar = MissingPairedCall<isFoo/1, isBar/1>;

from AdaNode call
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
    exists(Expr call | DataFlow::isCallTo(call, "My_App.Db.Execute") |
      n.asExpr() = DataFlow::getAnArgument(call)
    )
  }
  // ... or only one formal of it:
  //   DataFlow::isArgumentFor(call, n.asExpr(), "Query")

  // Values that passed a validator are clean.
  predicate isBarrier(DataFlow::Node n) {
    exists(Expr call | DataFlow::isCallTo(call, "My_App.Validate.Sanitize") |
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
    exists(Expr call |
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
`.expected` — is how every shipped query is tested, and is what the
`ql/test` pack (`ada-tests`, depending on `ada-queries`, see
[The packs](#the-packs)) exists for. `ql/test/extractor/` holds a
different kind of test: test-local `.ql` files with no `.qlref`,
used for golden-output checks on the extractor itself (e.g. `PrintAst.ql`
dumps every node's kind/parent/index to guard the extraction pipeline
independent of any specific query). You won't need this pattern for a normal
query addition — it's for changes to the extractor or generator.
`ql/test/library/` uses a third kind: inline expectations, where the
expected result is a `-- $ tag=value` comment on the line it belongs to
(`codeql.ada.test.InlineExpectationsTest`; `ql/test/library/TaintTracking`
is a short example). It suits library predicates that report many small
facts.
