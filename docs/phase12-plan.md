# Phase 12 work plan — a semantic library layer

> **Done 2026-10-08.** What was built differs from this plan in a few places, recorded
> in BURNDOWN.md (Phase 12) and D-027: the type class is `Type`, not `TypeDecl` (a
> generated name); `Component` was added; generic subprograms are `Subprogram`s;
> `BasicDecl.getBody()` became `getCompletion()`; call resolution is shared with data
> flow through a parameterised module rather than wrapped from it.

**The goal of this phase is that writing an Ada query feels like writing a Java one.**
The benchmark is GitHub's Java library, where the parameters of a method are

```ql
from Method m, Parameter p
where m.hasQualifiedName("pkg", "Formulas", "freeAll") and p = m.getAParameter()
select p, p.getType()
```

and the results read `f`, `Formula`. "What are the parameters of
`AdaSAT.Formulas.Free_All`?" should read like this:

```ql
from Subprogram s, Parameter p
where s.hasQualifiedName("AdaSAT.Formulas.Free_All") and p = s.getAParameter()
select p, p.getName(), p.getMode(), p.getType()
```

Today it takes a cast to `Raw::ClassicSubpDecl` or `Raw::BaseSubpBody`, a four-level walk
(`getSubpSpec().getSubpParams().getParams().getChild(_)`), a second walk for grouped names
(`A, B : T`), and it returns every parameter twice, once for the spec and once for the
body. The library knows how to do all of this already. It is just not exposed.

---

## Priority: after v0.2.0, not before testers

Nobody is expected to write their own queries during the first round of external
testing, so this phase does not block it. It pays off in three places, in this order:

1. **The shipped queries.** 24 of the 25 queries in `ql/src/queries` use `Raw::`, and
   each rebuilds its own notion of "subprogram", "parameter" or "call". They do not
   agree. `ada/direct-recursion` decides what a call is by `Raw::CallExpr` plus
   `getReferencedDecl`, while data flow uses `SsaImpl::getCallTarget`. The first
   misses a parameterless recursive call written `Foo;` (an `Identifier` in a
   `CallStmt`, not a `CallExpr`), and calls through renamings. One `Call` class fixes
   that class of bug for every query at once.
2. **The next queries.** The security catalogue (Phase 11) needs sources and sinks
   written by people other than the author of the data-flow library. Each one is a
   few lines on top of `Call` and `Parameter`, or a page of `Raw::` without them.
3. **Testers who do write queries, later.** The first thing a CodeQL user does with a
   new language is write `from Function f select f`. Today that fails.

---

## What this phase is *not*

- **Not new analysis.** Every class wraps logic that exists and is tested: the call
  graph and argument binding in `SsaImpl.qll` (Phase 9), spec/body pairing
  (`ada_body_part`, D-021), qualified names, renaming resolution, types
  (`ada_expr_type`). If a task needs a new relation in the dbscheme, stop: that is an
  extractor change and a separate decision.
- **Not a fix for the named v1 limitations.** Dispatching calls, access-to-subprogram
  calls and calls into generic instances stay as they are (`docs/dataflow-design.md`).
  The new classes inherit them, and their documentation says so.
- **Not a replacement for `Raw::`.** The generated layer stays complete and remains
  the way to reach anything the semantic layer does not cover. `docs/ast-reference.md`
  stays its reference.

---

## Design

### What makes the Java library easy, and where Ada stands

| Java has | Ada today | This phase |
|---|---|---|
| Semantic classes: `Method`, `Parameter`, `MethodCall`, `Field`, `Class` | `BasicDecl`, `Name`, `Expr` and little else | `Subprogram`, `Parameter`, `Call`, `Package`, `TypeDecl`, `Variable` (below) |
| Syntax classes with no prefix: `IfStmt`, `ReturnStmt`, `AddExpr` | Every one needs `Raw::` (`Raw::IfStmt`) | All generated classes usable unqualified (Task 12.0) |
| Results print as names: `freeAll`, `f` | Results print as class names: `SubpDecl`, `DefiningName` | Readable `toString` (Task 12.0) |
| Uniform verbs: `getName`, `hasName`, `hasQualifiedName`, `getAParameter`, `getType`, `getEnclosingCallable` | Mixed: `getAName`, `getText`, `getADefiningName` | The same verbs, `get`/`getA`/`has` as Java uses them |
| One declaration per entity | Spec and body are two | The canonical-declaration rule (below) |

### No prefix: the generated classes become public

Java parity means `from IfStmt s` works, not `from Raw::IfStmt s`. GitHub's Swift and
Rust libraries, which are generated from a schema the same way, already do this. A
generated class is exported under its own name, and a hand-written class with the same
name (`BasicDecl`, `Name`, `Expr`) extends the generated one and takes its place. The
`Raw` module stays as it is: an internal name that queries no longer write. Writing
`Raw::` stays possible, for code that wants the bare generated class explicitly.

### Readable results

A node's `toString` is what the results view and SARIF messages show. Today that is
the class name. Like Java's, it becomes the thing the node is: a declaration prints its
name (`Free_All`), a name its text (`F.Length`), a call its callee (`Append (...)`),
a literal its value, and only nodes with nothing better print their class.
`getAPrimaryQlClass` still gives the class, so View AST and the AST printers
(`codeql.ada.PrintAst`) keep their labels.

### Same nodes, more meaning

Every new class `extends` a Raw class, as the existing hand-written ones do
(`BasicDecl extends Raw::BasicDecl`). There are no synthetic nodes and no new
relations. A query can always cast between the layers, and View AST shows the same
nodes either way.

### One entity, one node: the canonical declaration

The main design choice. In Ada a subprogram with a separate spec is declared twice
(the spec, the body) and possibly three times (a body stub `is separate`). A QL class
is a set of nodes and cannot merge two nodes into one, so the layer picks one node to
stand for the entity:

- **A `Subprogram` is its first declaration:** the spec (`SubpDecl`) when one exists,
  otherwise the body. `getBody()` reaches the body (through `ada_body_part`, and the
  stub when separate), `getSpec()` the spec if any, `getADeclaration()` any of them.
- **A `Parameter` is the defining name in the canonical declaration's `ParamSpec`.**
  `getBodyDeclaration()` gives the matching defining name in the body, which is the
  one references inside the body resolve to (noted in `UnusedParameter.ql`).
- `Package` follows the same rule (the spec, else the body).

The consequence: `hasQualifiedName` yields one `Subprogram`, and the `Free_All` query
above returns one row, not two. The cost: "the parameter a reference resolves to" is
not the canonical `Parameter` when the reference is in a body, so `Name` gets a
helper, `getReferencedParameter()`, that maps it.

### Calls are resolved calls

`Call` is every expression `SsaImpl::getCallTarget` resolves: named calls with and
without parentheses, prefixed views (`Obj.Op`), protected operations, user-defined
operators, through renamings. An unresolved call is not a `Call`, because syntactically
`F (X)` may also be an index or a type conversion, and guessing is what the corpus
triage (Task 9.6, defect C) showed goes wrong. Queries that need a textual fallback
keep using the D-026 pattern explicitly. Whether to add an `UnresolvedCall` class for
those is open question 2.

---

## The classes

| Class | Extends | Main predicates | Wraps |
|---|---|---|---|
| `Subprogram` | `Raw::BasicDecl` | `getName`, `getQualifiedName` (inherited), `getAParameter`, `getParameter(i)`, `getNumberOfParameters`, `getReturnType`, `isFunction`, `isProcedure`, `getSpec`, `getBody`, `getADeclaration`, `getACall`, `isExpressionFunction`, `isImported` | `getSubpSpecOf`, `formalAt`, `ada_body_part` |
| `Parameter` | `Raw::DefiningName` | `getName`, `getMode` (`"in"`, `"out"`, `"in out"`, `"access"`), `isIn`, `isOut`, `getTypeDecl`, `getTypeExpr`, `getDefaultExpr`, `getIndex`, `getSubprogram`, `getBodyDeclaration` | `formalAt`, `anyFormalName` |
| `Call` | `Raw::Expr` | `getTarget` (renamings followed), `getArgument(i)`, `getArgumentFor(Parameter)`, `getArgumentByName(string)`, `getAnArgument`, `getEnclosingSubprogram`, `isStatement` | `getCallTarget`, `resolveSubpRenaming`, `callActual` |
| `Package` | `Raw::BasicDecl` | `getName`, `getSpec`, `getBody`, `getADeclaration` (what it declares), `getPrivatePart`, `isGenericInstance` | `ada_body_part` |
| `TypeDecl` | `Raw::BaseTypeDecl` | `getName`, `isRecord`, `isEnumeration`, `isAccess`, `isArray`, `isTagged`, `getAComponent`, `getAnEnumerationLiteral` | Raw accessors |
| `Variable` | `Raw::DefiningName` | `getName`, `getTypeDecl`, `getInitializer`, `isConstant`, `getAnAccess`, `getEnclosingSubprogram` | `ObjectDecl`, `ada_xref` |

Also: `Name.getReferencedParameter()` and `Name.getReferencedVariable()`;
`Expr.getType()` stays. The existing `DataFlow::isCallTo`, `getCallTarget`,
`getAnArgument`, `isArgumentAt` and `isArgumentFor` become one-line aliases over `Call`.
They are kept, so `CommandInjection.qll` and user-written sinks keep working.

The table is the starting point, not a promise. A predicate goes in only when a shipped
query, a test, or the query-writing guide uses it.

---

## Tasks

### 12.0 No prefix, readable results (D-027) — 1 day

Two changes that need no new classes, done first because every later task builds on them:

- **Export the generated classes unqualified.** `generator/gen.py` emits, next to the
  `Raw` module, one public alias or subclass per generated class, skipping the names a
  hand-written class takes (`BasicDecl`, `Name`, `Expr`, `AdaNode`, ...). `from IfStmt s`
  then compiles. Name clashes with the new semantic classes are settled here: `Call`,
  `Parameter`, `Package` and `Variable` are not Libadalang node names, so the main risk
  is `SubpBody` vs `SubprogramBody`, which exists twice today and is merged.
- **Readable `toString`,** as in Design. Check that no test `.expected` file changes
  except where a test prints nodes, and that those changes read better.

Acceptance: full suite green (`.expected` diffs reviewed), corpus per-query counts
unchanged, SARIF messages from one corpus project compared by eye.

**Why not rename `Raw`?** With the classes exported unqualified, queries stop writing
the module name, so what it is called hardly matters. `Raw` is GitHub's own name for
the same thing in Swift and Rust. Renaming it (to `Syntax`, the best candidate) would
touch ~870 lines for no gain to anyone writing queries. Recorded as D-027 with the
exported-classes decision.

### 12.1 `Subprogram` and `Parameter` — 1.5 days

The canonical-declaration rule, both classes, `Name.getReferencedParameter()`.

Fixture `ql/test/library/Semantic/Subprograms/`, with inline expectations, covering:
spec and body in one package; spec in `.ads`, body in `.adb`; a body with no spec; a
separate body (stub); an expression function; grouped parameters (`A, B : in T`); all
four modes; defaults; a function vs a procedure; an imported subprogram; a generic
subprogram and an instance of it (limitation pinned as `MISSING:`); a renaming.

**Acceptance:** each case has exactly one `Subprogram`; `getAParameter` agrees with
`SsaImpl::formalAt` on every subprogram in the five corpus databases (a consistency
query in `ql/debug/`, empty).

### 12.2 `Call` — 1 day

`Call` over `getCallTarget`, arguments over `callActual`; the `DataFlow` helpers
rewritten as aliases.

Fixture `Semantic/Calls/`: call with and without parentheses, as statement and as
expression, positional, named and mixed associations, defaulted formals, prefixed view,
protected operation, user-defined operator, call through a renaming, a type conversion
and an index (no `Call`), an unresolved call (no `Call`).

**Acceptance:** the full DataFlow and TaintTracking tests unchanged; `Call` and
`DataFlow::getCallTarget` agree on the corpus.

### 12.3 `Package`, `TypeDecl`, `Variable` — 1 day

Fixture `Semantic/Declarations/`. Same canonical rule for packages.

### 12.4 Port the shipped queries — 1 day

Rewrite each of the 24 queries where the layer makes it shorter or more consistent.
Not where it doesn't: a query about syntax (`ada/goto-statement`) stays syntactic.

**Acceptance:** `python3 scripts/corpus_queries.py` against the baseline. Every count
that changes is triaged and explained in the commit, as in Task 9.6. Expect at least
`ada/direct-recursion` to gain results (parameterless and renamed recursive calls);
each new one is checked to be a true positive before the baseline is refreshed.

### 12.5 Documentation — half a day

- `docs/query-writing.md`: "start here" rewritten around the semantic classes, with a
  short "if you know CodeQL for Java" table (`Method` → `Subprogram`, `MethodCall` →
  `Call`, `Field`/`LocalVariable` → `Variable`, `Class` → `TypeDecl`/`Package`).
  The generated syntax classes are "everything else", without a prefix; `Raw::` is
  mentioned once, as the module they come from.
- `docs/ast-reference.md`: unchanged in content, prefixes dropped from the examples;
  a note at the top pointing to the semantic layer first.
- The `Free_All` example as the first query in the guide.

**Total: about 6 days.**

---

## Open questions (decide before 12.1)

1. **Ada names or Java names?** `Subprogram`, not `Method`/`Function`, because Ada
   users say "subprogram" and the Ada RM does. Predicate *verbs* follow Java
   (`getAParameter`, `getEnclosingCallable` → `getEnclosingSubprogram`). Recommendation:
   Ada nouns, Java verbs.
2. **`UnresolvedCall`.** A syntactic "looks like a call and does not resolve" class
   would let the D-026 text fallback in `unused-*` and `dead-local-subprogram` use a
   class instead of repeated patterns. Useful, but it bakes a heuristic into the
   library. Recommendation: not in this phase; revisit after 12.4 shows how many
   queries would use it.
3. **Predefined entities.** Should `Subprogram` include runtime subprograms
   (`Ada.Text_IO.Put_Line`, extracted as pseudo-sources, D-026)? They are needed as
   call targets (`c.getTarget().hasQualifiedName("Ada.Text_IO.Put_Line")`), so
   recommendation: yes, with `fromSource()` excluding them where a query reports.

---

## Risks

- **Performance.** The canonical-declaration rule joins `ada_body_part` for every
  subprogram, and `Parameter` maps body names back to spec names. Both are small
  relations, but check `codeql query run --evaluator-log` on gpr2 (the largest corpus
  project) after 12.1.
- **Two ways to do everything.** With both layers public, examples drift. The guide
  must show the semantic layer first and the generated layer as the fallback, and
  12.4 should leave no shipped query mixing them without reason.
- **API churn.** Renaming or reshaping predicates is free now (no external query
  authors, v0.x) and expensive later. That is an argument for doing this phase before
  anyone outside starts writing queries, not after.
