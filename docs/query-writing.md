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
- **`ql/src`, published as `peter-villadsen/ada-queries`** — the 8 shipped
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
style/maintainability respectively; see the 8 shipped queries for examples
of each. `@kind table` (arbitrary tuples, no location/message shape) exists
for exploratory or diagnostic queries, but such a query can't be interpreted
by `database analyze` — only run directly (`codeql query run`) or by
`codeql test run` in a test fixture.

## Adding a query

1. Write `ql/src/queries/YourQuery.ql`. The 8 existing queries in that
   directory are templates — `UnusedVariable.ql` and `TodoComment.ql` are
   good starting points if your query is a single `from`/`where`/`select`
   over one node type; `HardcodedCredential.ql` shows a multi-variable
   `from` with a name-pattern heuristic.
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
   passes — that's your regression test from now on. (If you see a
   reference to `codeql test run --learn` elsewhere: that flag doesn't exist
   on the CodeQL CLI version this project targets; `codeql test accept` is
   the actual mechanism, verified above.)
4. Run the full suite before committing:
   ```sh
   codeql test run ql/test --additional-packs=ql --search-path=extractors
   ```

### Testing a query

The pattern above — `.qlref` pointing at the real query, plus fixtures, plus
`.expected` — is how all 8 shipped queries are tested, and is what the
`ql/test` pack (`ada-tests`, depending on `ada-queries`, see
[The two packs](#the-two-packs)) exists for. `ql/test/extractor/` holds a
different kind of test: test-local `.ql` files with no `.qlref`,
used for golden-output checks on the extractor itself (e.g. `PrintAst.ql`
dumps every node's kind/parent/index to guard the extraction pipeline
independent of any specific query). You won't need this pattern for a normal
query addition — it's for changes to the extractor or generator.
