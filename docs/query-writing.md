# Writing queries

This is a guide to adding your own query to this project (or forking it to
build a private one). It assumes you've read the
[user guide](user-guide.md) and know what a database and a QL pack are; it
does not assume prior QL experience.

## Start here

If you have written CodeQL queries for Java, an Ada query reads the same way.
The parameters of a subprogram called Free_All in AdaSAT.Formulas:

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
   - `IndirectRecursion.ql`: the call graph and transitive closure.
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
- **`ql/src`, published as `peter-villadsen/ada-queries`** — the 26 shipped
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
| `MetricSubprogram` (`Subprogram.getMetrics()`) | `getNumberOfStatements`, `getCyclomaticComplexity`, like Java's `MetricCallable` |

Two things differ from Java because Ada differs:

- **Declared twice, counted once.** A subprogram with a spec in the `.ads` and a
  body in the `.adb` is two AST nodes. `Subprogram` is the first of them (the
  spec when there is one), so `hasQualifiedName` finds one subprogram, not two.
  `getBody()` and `getADeclaration()` reach the others. Its parameters are the
  spec's; `Parameter.getAnAccess()` finds the uses in the body, which resolve to
  the body's copy.
- **Generic subprograms and their instances.** A generic subprogram is a
  `Subprogram` (`isGeneric()`); an instance of one (`procedure P is new G (...)`) is
  not, and a call to an instance targets the generic: `getTarget()` of `Free (X)` is
  `Ada.Unchecked_Deallocation`, and its parameters are the generic's.
- **What `Call` does not cover.** A dispatching call's `getTarget()` is its
  static target, and a call through an access-to-subprogram value is not a
  `Call`. Data flow follows both: into every override
  (`Subprogram.getAnOverride()`), and into the subprograms whose `'Access` reaches
  the call (`docs/dataflow-design.md`). A private type and its full declaration are two
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
| `AdaNode.getEnclosingSubprogram()` | The `Subprogram` whose body most closely encloses the node, like Java's `getEnclosingCallable()` |
| `AdaNode.getAnEnclosingBody()` / `getEnclosingUnit()` | Any subprogram body around the node, at any depth / the containing compilation unit |
| `File.isPredefined()` | The file is a predefined pseudo-source |
| `Comment` | Source comments: token trivia in Libadalang, not AST nodes, so a separate hand-written relation (`ada_comments`), not part of the node tree |

Results show what a node is: a declaration by its name (`Free_All`), an
expression by a short rendering (`F.Length`, `Append (...)`, `... = ...`), a
statement by its leading keywords (`if ...`, `raise Constraint_Error`).
`getAPrimaryQlClass()` gives the class.

Reach for the semantic classes first, and the AST classes for the shape of the
code. Beyond these, `codeql.ada.controlflow.ControlFlowGraph` gives the control-flow graph
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

The extension creates `ql/lib/codeql-pack.lock.yml` for each View AST run and
deletes it afterwards (its log says "Deleting temporary package lock file"). That
file is not committed (`.gitignore`), so this is harmless; `codeql pack install
ql/lib` recreates it when the command line needs it. While
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
   Whatever you report, add `x.fromSource()` (on any AST node or comment)
   so nothing is reported inside a predefined pseudo-source (D-026).
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
import codeql.ada.controlflow.ControlFlowGraph
import codeql.ada.controlflow.PairedCalls

// The module works on call statements (`Foo (X);`), as `OpenWithoutClose.ql` does.
private predicate isFoo(AdaNode call) {
  call.(CallStmt).getCall().(Call).getTarget().hasQualifiedName("My_App.Foo")
}

private predicate isBar(AdaNode call) {
  call.(CallStmt).getCall().(Call).getTarget().hasQualifiedName("My_App.Bar")
}

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
  as predefined pseudo-sources (D-026), so `Call.getTarget()` on a call to
  `Ada.Text_IO.Open` is its declaration in `a-textio.ads`, whether it was
  spelled in full or through a `use` clause or package renaming, and through
  subprogram renamings. Identify it with
  `hasQualifiedName("Ada.Text_IO.Open")` (case-insensitive; Libadalang's fully
  qualified name, extracted for every declaration). For something that is not
  a call, `Name.getReferencedDecl()` and `BasicDecl.getUltimateDecl()` do the
  same (`GenericInstantiation.getDesignatedGeneric()` already sees through
  generic renamings). Runtime units resolve only if a GNAT
  runtime was found at extraction (see the user guide); `Standard` always
  does. The pattern the shipped queries use (`isTextIoOp` in
  `OpenWithoutClose.ql`, `UncheckedConversion.ql`, ...) is: match
  semantically, and fall back to the name's text only when it does not
  resolve at all. Test it with a case only the semantic match catches (a
  renaming), so the test fails if resolution stops working.
- **Report only project code.** Every query restricts its reported element
  with `fromSource()` (on `AdaNode` and `Comment`), so nothing is reported
  inside a predefined file (D-026).

## Example: recursion at any depth

The call graph is a relation like any other, so QL's transitive closure finds cycles
of any length: `calls+(a, b)` is "a reaches b in one or more calls", `calls*` in zero
or more. This query lists every subprogram that can call itself, directly or through
other subprograms (P -> Q -> R -> P):

```ql
/**
 * @name Recursive subprogram
 * @description A subprogram that can call itself, directly or through other
 *              subprograms (P -> Q -> R -> P). Recursion uses stack space that grows
 *              with its depth, a concern where the stack size is fixed.
 * @kind problem
 * @id my-app/recursive-subprogram
 * @problem.severity recommendation
 */

import ada

/** Holds if `caller` contains a call to `callee`. */
predicate calls(Subprogram caller, Subprogram callee) {
  exists(Call c | c.getCaller() = caller and c.getTarget() = callee)
}

from Subprogram s, Subprogram next
where
  s.fromSource() and
  // `next` is the first subprogram on a cycle back to `s` (`s` itself if it calls
  // itself directly); if there are several, the one declared first
  next =
    min(Subprogram n |
      calls(s, n) and calls*(n, s)
    |
      n order by n.getLocation().getStartLine(), n.getLocation().getStartColumn()
    )
select s, "This subprogram is recursive: it calls $@, which leads back to it.", next, next.getName()
```

```ada
procedure Cycles is
   procedure P (N : Natural);
   procedure Q (N : Natural);
   procedure R (N : Natural);

   procedure P (N : Natural) is          --  P -> Q -> R -> P
   begin
      if N > 0 then
         Q (N - 1);
      end if;
   end P;

   procedure Q (N : Natural) is
   begin
      R (N);
   end Q;

   procedure R (N : Natural) is
   begin
      P (N);
   end R;

   function Fact (N : Natural) return Natural is   --  direct recursion
     (if N = 0 then 1 else N * Fact (N - 1));

   procedure Leaf is null;                 --  not recursive
   procedure Calls_Cycle is                --  calls into the cycle, not part of it
   begin
      P (3);
      Leaf;
   end Calls_Cycle;
begin
   Calls_Cycle;
   if Fact (3) = 6 then
      null;
   end if;
end Cycles;
```

It reports P, Q and R, each with the next subprogram on the cycle, and `Fact`, which
calls itself; not `Leaf`, and not `Calls_Cycle`, which calls into the cycle without
being part of it. The shipped queries split the two cases: `ada/direct-recursion` for
a subprogram that calls itself, `ada/indirect-recursion` for one that comes back to
itself through others. Like every `Call`-based query, it sees only calls that resolve:
not dispatching calls (bound to their static target) or calls through
access-to-subprogram values. Data flow follows both.

## Data flow and taint tracking

To ask "can this value reach that call?", import `codeql.ada.dataflow.DataFlow` and
`codeql.ada.dataflow.TaintTracking`. Then write a module implementing
`DataFlow::ConfigSig` (`isSource`, `isSink`, and optionally `isBarrier`) and instantiate
`TaintTracking::Global<Config>`. Use `DataFlow::Global<Config>` instead when only an
unchanged value counts. Flow crosses subprogram boundaries: into a subprogram through
its parameters, and back out through function results and `out` parameters.

A data-flow node is an expression (`n.asExpr()`) or a parameter as it receives the
caller's value (`n.asParameter()`, the parameter's name in the body, so
`n.asParameter() = p.getADeclaration()` for a `Parameter p`).

The examples below are complete queries. Each is also a test, in
`ql/test/examples/<name>/`, run against the Ada shown with it, so they are known to
work as written. Copy one, change the names, and keep the fixture next to it.

### Untrusted data reaches a subprogram

Make every argument of a call to the subprogram a sink, the values that should not
reach it the sources, and the values a validator returns barriers:

```ql
/**
 * @name Untrusted data reaches My_App.Db.Execute
 * @description A value from the command line or from a request reaches the query
 *              that My_App.Db.Execute runs without passing My_App.Validate.Sanitize.
 * @kind path-problem
 * @id my-app/untrusted-to-execute
 * @problem.severity error
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking
import codeql.ada.security.CommandInjection

module Config implements DataFlow::ConfigSig {
  // What counts as untrusted: the command line (the library's built-in source) and
  // the parameters of the request handler.
  predicate isSource(DataFlow::Node n) {
    n instanceof CommandInjection::Source
    or
    exists(Parameter p | p.getSubprogram().hasQualifiedName("My_App.Server.Handle_Request") |
      n.asParameter() = p.getADeclaration()
    )
  }

  // Every argument of every call to My_App.Db.Execute.
  predicate isSink(DataFlow::Node n) {
    exists(Call c | c.getTarget().hasQualifiedName("My_App.Db.Execute") |
      n.asExpr() = c.getAnArgument()
    )
  }

  // What Sanitize returns is clean.
  predicate isBarrier(DataFlow::Node n) {
    exists(Call c | c.getTarget().hasQualifiedName("My_App.Validate.Sanitize") | n.asExpr() = c)
  }
}

module Flow = TaintTracking::Global<Config>;

import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink) and sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This query depends on $@.", source.getNode(), "untrusted data"
```

On this code:

```ada
   --  a helper the value passes through on its way to Execute
   procedure Run_Query (Q : String) is
   begin
      Db.Execute (Q);                                --  BAD: from the command line, via Main
   end Run_Query;

   package body Server is
      procedure Handle_Request (Body_Text : String) is
      begin
         Db.Execute ("SELECT " & Body_Text);         --  BAD: request input
         Db.Execute (Validate.Sanitize (Body_Text)); --  fine: sanitized
      end Handle_Request;
   end Server;

   procedure Main is
   begin
      Run_Query (Ada.Command_Line.Argument (1));
      Db.Execute ("SELECT 1");                       --  fine: a constant
   end Main;
```

it reports `Db.Execute (Q)`, with the path from `Ada.Command_Line.Argument (1)` in
`Main` through `Run_Query`'s parameter, and `Db.Execute ("SELECT " & Body_Text)`; not
the sanitized call or the constant one. To make one parameter the sink rather than
every argument, use `n.asExpr() = c.getArgumentByName("Query")`.

### An environment variable names a file to delete

Sources and sinks in the GNAT runtime are written the same way: the runtime units a
project uses are extracted (D-026), so `Ada.Environment_Variables.Value` and
`Ada.Directories.Delete_File` resolve like the project's own subprograms.

```ql
/**
 * @name Environment variable decides which file is deleted
 * @description The value of an environment variable reaches the name of a file or
 *              directory that is deleted. Whoever sets the environment chooses what
 *              is removed.
 * @kind path-problem
 * @id my-app/environment-to-file-deletion
 * @problem.severity warning
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking

module Config implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) {
    exists(Call c | c.getTarget().hasQualifiedName("Ada.Environment_Variables.Value") |
      n.asExpr() = c
    )
  }

  predicate isSink(DataFlow::Node n) {
    exists(Call c |
      c.getTarget()
          .hasQualifiedName([
              "Ada.Directories.Delete_File", "Ada.Directories.Delete_Directory",
              "Ada.Directories.Delete_Tree"
            ])
    |
      n.asExpr() = c.getArgument(0)
    )
  }
}

module Flow = TaintTracking::Global<Config>;

import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink) and sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "The file deleted here is named by $@.", source.getNode(),
  "an environment variable"
```

```ada
with Ada.Directories;
with Ada.Environment_Variables;

procedure Cleanup is
   function Work_Dir return String is (Ada.Environment_Variables.Value ("WORK_DIR"));

   procedure Remove (Path : String) is
   begin
      Ada.Directories.Delete_File (Path);  --  BAD: from WORK_DIR, via Work_Dir and Remove
   end Remove;

   Lock_File : constant String := "/tmp/cleanup.lock";
begin
   Remove (Work_Dir & "/cache.dat");
   Remove (Lock_File);                     --  fine on its own: a constant
   Ada.Directories.Delete_Tree (Ada.Environment_Variables.Value ("TMP_TREE"));  --  BAD
end Cleanup;
```

Both deletions are reported. The first path runs from `Value` through the expression
function `Work_Dir`, the concatenation `Work_Dir & "/cache.dat"`, and `Remove`'s
parameter to `Delete_File (Path)`. `Remove (Lock_File)` adds no result: the same sink,
but no source reaches it from there.

### A public parameter names a file

The semantic classes combine with data flow. The sources here are the parameters of
every subprogram in a package's visible part:

```ql
/**
 * @name Public parameter names a file
 * @description A parameter of a subprogram in a package's visible part reaches the
 *              name of a file that is opened or created, so every caller of the
 *              package decides which file it touches.
 * @kind path-problem
 * @id my-app/parameter-to-file-name
 * @problem.severity recommendation
 */

import ada
import codeql.ada.dataflow.DataFlow
import codeql.ada.dataflow.TaintTracking

module Config implements DataFlow::ConfigSig {
  // The parameters of every subprogram declared in the visible part of a package.
  predicate isSource(DataFlow::Node n) {
    exists(Package pkg, Parameter p |
      pkg.fromSource() and
      p.getSubprogram() = pkg.getAPublicMember() and
      n.asParameter() = p.getADeclaration()
    )
  }

  // The `Name` argument of Ada.Text_IO.Open and Create, positional or named.
  predicate isSink(DataFlow::Node n) {
    exists(Call c |
      c.getTarget().hasQualifiedName(["Ada.Text_IO.Open", "Ada.Text_IO.Create"]) and
      n.asExpr() = c.getArgumentByName("Name")
    )
  }
}

module Flow = TaintTracking::Global<Config>;

import Flow::PathGraph

from Flow::PathNode source, Flow::PathNode sink
where Flow::flowPath(source, sink) and sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This file name comes from $@.", source.getNode(),
  "a public parameter"
```

```ada
package Logs is
   procedure Open_Log (File_Name : String);  --  public: its caller picks the file
   procedure Rotate;
private
   procedure Reopen (Name : String);         --  private: not part of the interface
end Logs;
```

```ada
   procedure Open_Log (File_Name : String) is
   begin
      Ada.Text_IO.Open (Log, Ada.Text_IO.Append_File, File_Name);  --  BAD
   end Open_Log;

   procedure Reopen (Name : String) is
   begin
      Ada.Text_IO.Open (Log, Ada.Text_IO.Append_File, Name);       --  fine: private
   end Reopen;
```

`Open_Log`'s `File_Name` is reported; `Reopen`'s `Name` is not, since `Reopen` is
declared in the private part. `getArgumentByName("Name")` finds the third argument of
`Open` although it is written positionally.

### Storage that is not provably deallocated

Data flow can also show that something does *not* happen. This query lists every
allocation (`new`) whose access value never provably reaches a deallocation, a call
`Free (X)` of an instance of `Ada.Unchecked_Deallocation`. It uses `DataFlow::Global`,
not taint tracking: the access value itself must arrive, not something computed from
it.

```ql
/**
 * @name Allocation not provably deallocated
 * @description Storage allocated with `new` whose access value cannot be shown to
 *              reach a deallocation (`Free (X)`, an instance of
 *              Ada.Unchecked_Deallocation). Either the storage is never released, or
 *              it is released in a way the data-flow library does not follow
 *              (docs/known-limitations.md).
 * @kind problem
 * @id my-app/allocation-not-provably-deallocated
 * @problem.severity recommendation
 */

import ada
import codeql.ada.dataflow.DataFlow

module Config implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { n.asExpr() instanceof Allocator }

  // The access value handed to a deallocation: a call to an instance of
  // Ada.Unchecked_Deallocation targets the generic.
  predicate isSink(DataFlow::Node n) {
    exists(Call free |
      free.getTarget().hasQualifiedName("Ada.Unchecked_Deallocation") and
      n.asExpr() = free.getArgument(0)
    )
  }
}

module Flow = DataFlow::Global<Config>;

from Allocator alloc, DataFlow::Node n
where
  n.asExpr() = alloc and
  not Flow::flow(n, _) and
  alloc.fromSource()
select alloc, "This storage is not provably deallocated."
```

```ada
with Ada.Unchecked_Deallocation;

procedure Storage is
   type Node;
   type Node_Access is access Node;
   type Node is record
      Value : Integer;
      Next  : Node_Access;
   end record;

   procedure Free is new Ada.Unchecked_Deallocation (Node, Node_Access);

   Shared : Node_Access;

   procedure Freed_Here is
      P : Node_Access := new Node'(1, null);       --  fine: freed below
   begin
      Free (P);
   end Freed_Here;

   procedure Release (P : in out Node_Access) is
   begin
      Free (P);
   end Release;

   procedure Freed_By_Helper is
      P : Node_Access := new Node'(2, null);       --  fine: freed in Release
   begin
      Release (P);
   end Freed_By_Helper;

   function Make return Node_Access is
   begin
      return new Node'(3, null);                   --  fine: the caller frees it
   end Make;

   procedure Freed_By_Caller is
      P : Node_Access := Make;
   begin
      Free (P);
   end Freed_By_Caller;

   procedure Never_Freed is
      P : Node_Access := new Node'(4, null);       --  BAD: never freed
   begin
      P.Value := 5;
   end Never_Freed;

   procedure Kept_In_Shared is
   begin
      Shared := new Node'(5, null);                --  fine: freed at the end, through Shared
   end Kept_In_Shared;

   procedure Linked is
      Head : Node_Access := new Node'(6, null);    --  fine: freed below
   begin
      Head.Next := new Node'(7, null);             --  fine: freed through the component
      Free (Head.Next);
      Free (Head);
   end Linked;
begin
   Freed_Here;
   Freed_By_Helper;
   Freed_By_Caller;
   Never_Freed;
   Kept_In_Shared;
   Linked;
   Free (Shared);
end Storage;
```

What it can prove, and so does not report: freeing in the same subprogram
(`Freed_Here`), through a helper's `in out` parameter (`Freed_By_Helper`, freed in
`Release`), by the caller of a function that returns the allocation
(`Freed_By_Caller`, through `Make`), through `Shared`, a variable of the enclosing
procedure that the nested `Kept_In_Shared` writes and `Free (Shared)` releases at the
end, and through a record component (`Head.Next`). It reports only `Never_Freed`,
whose storage is never released: a real leak.

A result still means "not proven", not "leaked": storage released through a gap in
data flow (`docs/known-limitations.md`), such as an entry's `out` formal, is reported
too, so read the results as a list of allocations whose release a reviewer has to
check by hand. Storage released by other means is not
recognised either: a controlled type's `Finalize`, a storage pool, or an access type
with a `Storage_Size` (whose storage is reclaimed when the type goes out of scope).

A call to an instance of a generic subprogram targets the generic, so
`free.getTarget()` is `Ada.Unchecked_Deallocation` whatever the instance is called.
`UncheckedDeallocation.ql` shows a fuller match, including the Ada 83 name
`Unchecked_Deallocation` and a fallback for databases built without the GNAT runtime.

### Adding to the built-in command-injection query

If the subprogram runs a command, extend `CommandInjection::Sink` in a `.qll` file
instead. Then write a copy of `CommandLineInjection.ql` that imports that file as well.
A subclass takes effect only in queries that import it.

```ql
class MyShellSink extends CommandInjection::Sink {
  MyShellSink() {
    exists(Call c | c.getTarget().hasQualifiedName("My_App.Shell.Run") |
      this.asExpr() = c.getArgumentByName("Command")
    )
  }
}
```

`CommandInjection::Source` and `CommandInjection::Barrier` extend the same way.

### Sources of untrusted data

`codeql/ada/security/FlowSources.qll` has the sources the security queries share, as in
CodeQL for other languages:

- **`RemoteFlowSource`**: data received from the network. `GNAT.Sockets.Receive_Socket`
  and `Receive_Vector` (the buffer they fill in), `T'Input (Stream (Socket))`, and AWS
  request data (`AWS.Status.Parameter`, `URI`, `Payload`, ..., `AWS.Parameters.Get`).
  `ada/path-injection` and `ada/sql-injection` use these.
- **`LocalUserInput`**: command-line arguments (`Ada.Command_Line.Argument`,
  `GNAT.Command_Line`), environment variables, and lines read from standard input. No
  shipped query uses these as sources by default: a command-line tool that opens the file
  it is given is doing its job. Use them in a query of your own when the local user is not
  trusted, a setuid program for instance.

Both are abstract classes: subclass one to add a source, such as the request data of a
web framework the library does not model. `getSourceType()` gives the text the query
message uses. A source that is an `out` parameter, like the buffer `Receive_Socket` fills
in, is the variable after the call: `DataFlow::isOutArgument(n, call, i)`.

```ql
class MyRequestField extends RemoteFlowSource {
  MyRequestField() {
    exists(Call c | c.getTarget().hasQualifiedName("My_Server.Requests.Field") |
      this.asExpr() = c
    )
  }

  override string getSourceType() { result = "HTTP request data" }
}
```

### What is followed

Calls resolve by meaning, not text, so `use` clauses and renamings are covered, and
`hasQualifiedName` matches every overload of a name. Names are the fully qualified
ones Libadalang computes: a subprogram nested in another is `Outer.Inner`. The
`DataFlow` module also has string-based helpers that predate the semantic classes
(`DataFlow::isCallTo`, `getAnArgument`, `isArgumentFor`, `isParameterOf`); they give the
same answers. How dispatching calls, access-to-subprogram values, components and
containers are followed is described in
[dataflow-design.md](dataflow-design.md), "Named v1 limitations" and "Taint tracking".
A test of your own query should route the value through at least one other
subprogram, so it fails if cross-procedure flow breaks.

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
`ql/test/examples/` holds the example queries of this guide, each next to
the Ada it is shown with. `ql/test/library/` uses a third kind: inline expectations, where the
expected result is a `-- $ tag=value` comment on the line it belongs to
(`codeql.ada.test.InlineExpectationsTest`; `ql/test/library/TaintTracking`
is a short example). It suits library predicates that report many small
facts.
