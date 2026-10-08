# Ada AST reference for query writers

What tree the extractor builds for common Ada constructs, and the traps in it. This
is the companion to [query-writing.md](query-writing.md). Every tree below is real
output from `ql/lib/tools/PrintAst.ql`, copied from the test
`ql/test/library/PrintAst` (fixtures `reference.adb`, `ref_pkg.ads`, `ref_pkg.adb`,
`test.adb`), with marker rows left out and long subtrees shortened to `...`. If the
extractor changes a shape, that test fails and this page must change with it.

For anything not covered here, look at the tree yourself: **CodeQL: View AST** in
VS Code, `tools/PrintAst.ql` on a scratch database, or `scripts/print_ast.py` for
text, JSON or XML (see query-writing.md, "Seeing the tree").

Many questions need no tree walking at all: subprograms, parameters, calls, types,
variables and packages have their own classes (`Subprogram`, `Parameter`, `Call`,
`Type`, `Variable`, `Package`; query-writing.md, "The library"). Use this page for
the shape of the code those classes do not cover.

## Reading a tree

Each line is one node:

```
accessor: Class token -> resolution
```

- **`accessor`** is the `Raw` predicate that gets from the parent to this node:
  `getSuffix`, `getName`, ... A list element shows `[i]` instead, and is reached
  with `getChild(i)`.
- **`Class`** is the node's `Raw` class (`n.getAPrimaryQlClass()`).
- **`token`** is the text of an identifier, literal or operator (`getValue()`).
- **`-> resolution`** is what a name resolves to (`Name.getReferencedDecl()`),
  shown as the qualified name of the defining name it denotes (for `A, B : T`, a
  reference to `B` shows `-> Pkg.B`; see [Name resolution](#name-resolution)). A
  declaration with no qualified name shows its class, names and position.

So this tree:

```
[1]: CallStmt
  getCall: CallExpr -> Reference.Log
    getName: Identifier Log -> Reference.Log
    getSuffix: AssocList
      [0]: ParamAssoc
        getRExpr: StringLiteral "hello"
```

is matched by

```ql
exists(CallStmt s, CallExpr c, ParamAssoc a |
  c = s.getCall() and
  c.getName().(Name).getText() = "Log" and
  a = c.getSuffix().(AssocList).getChild(0) and
  a.getRExpr().(StringLiteral).getValue() = "\"hello\""
)
```

### General rules

- **Classes and accessors come from Libadalang.** A kind `CallExpr` is
  `CallExpr`; a field `f_suffix` is `getSuffix()`. Libadalang's own
  documentation of a node kind applies.
- **Many accessors return a general type.** `CallExpr.getSuffix()` returns
  `AdaNode`, because it can be an `AssocList` (arguments) or a `BinOp` (a slice
  range). Cast to what you expect: `.getSuffix().(AssocList)`.
- **Lists are nodes.** `AssocList`, `StmtList`, `AdaNodeList`, `DefiningNameList`
  and the like sit between a parent and its elements. `getChild(i)` on the list
  gives the `i`th element; `getParentIndex()` on an element gives `i`.
- **A declared name is a `DefiningName` wrapping an `Identifier`.**
  `BasicDecl.getAName()` (hand-written layer) gives its text directly.
- **Optional keywords are marker nodes.** `constant` is `getHasConstant:
  ConstantPresent` and its absence `ConstantAbsent`; likewise `aliased`, `not null`,
  `all`, `tagged`, `limited`, `private`, `abstract`. Test them with
  `instanceof ConstantPresent`. The trees below omit the `…Absent` markers,
  `…Unspecified` (overriding indicators) and `ModeDefault` (no parameter mode
  written).
- **`StringLiteral.getValue()` includes the quotes**: `"abc"` is the six characters
  `"abc"` with quotes, so compare against `"\"abc\""`, or strip them.
- **Comments are not in the tree.** They are `Comment` (`ada_comments`), with their
  own location.

## Compilation units and context clauses

```ada
with Ada.Text_IO; use Ada.Text_IO;
```

```
CompilationUnit
  getPrelude: AdaNodeList
    [0]: WithClause
      getPackages: NameList
        [0]: DottedName -> Ada.Text_IO
          getPrefix: Identifier Ada -> Ada
          getSuffix: Identifier Text_IO -> Ada.Text_IO
    [1]: UsePackageClause
      getPackages: NameList
        [0]: DottedName -> Ada.Text_IO
          ...
  getBody: LibraryItem
    getItem: SubpBody | PackageDecl | PackageBody | ...
```

A file can hold several `CompilationUnit`s. `AdaNode.getEnclosingUnit()` walks up to
the one containing a node.

## Declarations

### Objects

```ada
P    : Ref_Pkg.Point := (X => 1, Y => 2);
A, B : Integer := 0;
Name : constant String := "abc";
```

```
[0]: ObjectDecl
  getIds: DefiningNameList
    [0]: DefiningName
      getName: Identifier P
  getTypeExpr: SubtypeIndication
    getName: DottedName -> Ref_Pkg.Point
      ...
  getDefaultExpr: Aggregate
    ...
[1]: ObjectDecl
  getIds: DefiningNameList
    [0]: DefiningName
      getName: Identifier A
    [1]: DefiningName
      getName: Identifier B
  getTypeExpr: SubtypeIndication
    getName: Identifier Integer -> Standard.Integer
  getDefaultExpr: IntLiteral 0
[5]: ObjectDecl
  getIds: DefiningNameList
    [0]: DefiningName
      getName: Identifier Name
  getHasConstant: ConstantPresent
  getTypeExpr: SubtypeIndication
    getName: Identifier String -> Standard.String
  getDefaultExpr: StringLiteral "abc"
```

**`A, B : Integer` is one `ObjectDecl` with two `DefiningName`s.** It is one
declaration, so "the declaration of `A`" and "the declaration of `B`" are the same
node. Compare defining names, not declarations, when the difference matters
(`Name.denotesSameEntityAs` does). Record components work the same way
(`ComponentDecl`).

An object renaming is an `ObjectDecl` with a `getRenamingClause`:

```ada
R : Integer renames A;
```

```
[6]: ObjectDecl
  getIds: ...  Identifier R
  getTypeExpr: SubtypeIndication
    getName: Identifier Integer -> Standard.Integer
  getRenamingClause: RenamingClause
    getRenamedObject: Identifier A -> Reference.A
```

### Types

```ada
type Point is record
   X, Y : Integer := 0;
end record;
type Color is (Red, Green, Blue);
subtype Small is Integer range 0 .. 9;
type Int_Array is array (Positive range <>) of Integer;
type Point_Access is access all Point;
type Shape is tagged record ...
```

```
[0]: ConcreteTypeDecl
  getName: DefiningName
    getName: Identifier Point
  getTypeDef: RecordTypeDef
    getRecordDef: RecordDef
      getComponents: ComponentList
          [0]: ComponentDecl
              [0]: DefiningName  (X)
              [1]: DefiningName  (Y)
            getComponentDef: ComponentDef
              getTypeExpr: SubtypeIndication
                getName: Identifier Integer -> Standard.Integer
            getDefaultExpr: IntLiteral 0
[1]: ConcreteTypeDecl
  getName: ... Identifier Color
  getTypeDef: EnumTypeDef
    getEnumLiterals: EnumLiteralDeclList
      [0]: EnumLiteralDecl
        getName: DefiningName
          getName: Identifier Red
      ...
[2]: SubtypeDecl
  getName: ... Identifier Small
  getSubtype: SubtypeIndication
    getName: Identifier Integer -> Standard.Integer
    getConstraint: RangeConstraint
      getRange: RangeSpec
        getRange: BinOp
          getLeft: IntLiteral 0
          getOp: OpDoubleDot ..
          getRight: IntLiteral 9
[3]: ConcreteTypeDecl
  getName: ... Identifier Int_Array
  getTypeDef: ArrayTypeDef
    getIndices: UnconstrainedArrayIndices
      getTypes: UnconstrainedArrayIndexList
        [0]: UnconstrainedArrayIndex
          getSubtypeName: Identifier Positive -> Standard.Positive
    getComponentType: ComponentDef
      getTypeExpr: SubtypeIndication
        getName: Identifier Integer -> Standard.Integer
[4]: ConcreteTypeDecl
  getName: ... Identifier Point_Access
  getTypeDef: TypeAccessDef
    getHasAll: AllPresent
    getSubtypeIndication: SubtypeIndication
      getName: Identifier Point -> Ref_Pkg.Point
[5]: ConcreteTypeDecl
  getName: ... Identifier Shape
  getTypeDef: RecordTypeDef
    getHasTagged: TaggedPresent
    getRecordDef: RecordDef
      ...
```

A derived type (`type Count is new Integer`) has `getTypeDef: DerivedTypeDef` with a
`getSubtypeIndication`. `BaseTypeDecl` covers every type and subtype
declaration; `Expr.getType()` returns one.

### Subprograms

A declaration, a body and an expression function:

```ada
procedure Move (S : in out Shape; By : Integer);   -- in the spec
procedure Move (S : in out Shape; By : Integer) is  -- in the body
begin
   S.Id := S.Id + By;
end Move;
function Twice (V : Integer) return Integer is (2 * V);
```

```
SubpDecl                       (the spec's declaration)
  getSubpSpec: SubpSpec
    ...
SubpBody
  getSubpSpec: SubpSpec
    getSubpKind: SubpKindProcedure
    getSubpName: DefiningName
      getName: Identifier Move
    getSubpParams: Params
      getParams: ParamSpecList
        [0]: ParamSpec
          getIds: DefiningNameList
            [0]: DefiningName
              getName: Identifier S
          getMode: ModeInOut
          getTypeExpr: SubtypeIndication
            getName: Identifier Shape -> Ref_Pkg.Shape
        [1]: ParamSpec
          ...  Identifier By
  getDecls: DeclarativePart
  getStmts: HandledStmts
    getStmts: StmtList
      [0]: AssignStmt
        ...
  getEndName: EndName -> Ref_Pkg.Move
    getName: Identifier Move -> Ref_Pkg.Move
ExprFunction
  getSubpSpec: SubpSpec
    getSubpKind: SubpKindFunction
    ...
    getSubpReturns: SubtypeIndication
      getName: Identifier Integer -> Standard.Integer
  getExpr: ParenExpr
    getExpr: BinOp
      getLeft: IntLiteral 2
      getOp: OpMult *
      getRight: Identifier V -> Reference.Twice.V
```

- **A declaration and its body are different nodes.** `BasicDecl.getCompletion()` goes
  from the declaration to the body; `BaseSubpBody.getDeclaration()` goes back
  (`ada_body_part`, D-021). A body with no separate declaration has neither.
- **Formals are grouped as written.** `(A, B : Integer; C : Float)` is two
  `ParamSpec`s, the first with two `DefiningName`s. To get the
  `i`th formal by position, count names, not `ParamSpec`s.
- **Modes** are `ModeIn`, `ModeOut`, `ModeInOut`, or `ModeDefault` when none is
  written (which means `in`).
- **The `end Move` name is a node** (`EndName`), and it resolves. Exclude it when
  counting references to a declaration.
- `BaseSubpBody` covers `SubpBody` and `ExprFunction` (and other body forms);
  `ClassicSubpDecl` covers `SubpDecl` and its relatives.

### Packages

```
PackageDecl
  getPackageName: DefiningName
    getName: Identifier Ref_Pkg
  getPublicPart: PublicPart
    getDecls: AdaNodeList
      [0]: ConcreteTypeDecl
      ...
PackageBody
  getPackageName: DefiningName
    getName: Identifier Ref_Pkg
  getDecls: DeclarativePart
    getDecls: AdaNodeList
      [0]: SubpBody
      ...
  getEndName: EndName -> Ref_Pkg
```

### Renamings, instantiations, pragmas and aspects

```ada
procedure Log (Msg : String) renames Put_Line;
package Int_IO is new Ada.Text_IO.Integer_IO (Integer);
pragma Inline (Twice);
Flag : Boolean := False with Volatile;
```

```
[7]: SubpRenamingDecl
  getSubpSpec: SubpSpec
    ...  Identifier Log, ParamSpec Msg
  getRenames: RenamingClause
    getRenamedObject: Identifier Put_Line -> Ada.Text_IO.Put_Line
[8]: GenericPackageInstantiation
  getName: DefiningName
    getName: Identifier Int_IO
  getGenericPkgName: DottedName -> Ada.Text_IO.Integer_IO
    ...
  getParams: AssocList
    [0]: ParamAssoc
      getRExpr: Identifier Integer -> Standard.Integer
[10]: PragmaNode
  getId: Identifier Inline
  getArgs: BaseAssocList
    [0]: PragmaArgumentAssoc
      getExpr: Identifier Twice -> Reference.Twice
[11]: ObjectDecl
  ...  Identifier Flag
  getDefaultExpr: Identifier False -> Standard.Boolean.False
  getAspects: AspectSpec
    getAspectAssocs: AspectAssocList
      [0]: AspectAssoc
        getId: Identifier Volatile
```

- `BasicDecl.getUltimateDecl()` follows renamings (subprogram, object, package,
  exception) to what is renamed.
- `GenericInstantiation.getDesignatedGeneric()` gives the generic. A call through an
  instance (`Int_IO.Put (A)`) resolves to the declaration *in the generic*
  (`-> Ada.Text_IO.Integer_IO.Put`), not to a copy per instance.
- A pragma's identifier is `getId().getValue()`; a named pragma argument has
  `getName()` (`Entity => X`). An aspect with a value (`External_Name => "x"`) has
  `getExpr()`.

## Statements

Statements sit in a `StmtList`, under a `HandledStmts` (`getStmts`) that also holds
the exception handlers (`getExceptions`).

### Assignment and calls

```ada
A := Twice (B);
Log ("hello");
New_Line;
Put_Line (Item => Name);
```

```
[0]: AssignStmt
  getDest: Identifier A -> Reference.A
  getExpr: CallExpr -> Reference.Twice
    getName: Identifier Twice -> Reference.Twice
    getSuffix: AssocList
      [0]: ParamAssoc
        getRExpr: Identifier B -> Reference.B
[1]: CallStmt
  getCall: CallExpr -> Reference.Log
    getName: Identifier Log -> Reference.Log
    getSuffix: AssocList
      [0]: ParamAssoc
        getRExpr: StringLiteral "hello"
[2]: CallStmt
  getCall: Identifier New_Line -> Ada.Text_IO.New_Line
[3]: CallStmt
  getCall: CallExpr -> Ada.Text_IO.Put_Line
    getName: Identifier Put_Line -> Ada.Text_IO.Put_Line
    getSuffix: AssocList
      [0]: ParamAssoc
        getDesignator: Identifier Item -> Ada.Text_IO.Put_Line.Item
        getRExpr: Identifier Name -> Reference.Name
```

- **A procedure call statement is a `CallStmt` wrapping the call.** Look for calls
  under `getCall()`, not as statements.
- **A call without parentheses is not a `CallExpr`.** `New_Line;` is a `CallStmt`
  whose `getCall()` is the bare `Identifier`. The same goes for a parameterless
  function call in an expression: `G : Integer := Get;` has `getDefaultExpr:
  Identifier Get -> Test.Get`. To find every call site of a subprogram, match names
  that resolve to it, not `CallExpr`s.
- **A named association** has `getDesignator()` (the formal's name, which resolves
  to the formal) and `getRExpr()` (the actual). A positional one has no
  designator. For data flow, `DataFlow::isArgumentFor` handles both.

### Three kinds of dotted call

```ada
S.Move (By => 2);       -- prefixed view: S is the first actual
Ref_Pkg.Move (S, 3);    -- expanded name: Ref_Pkg names the package
```

```
[4]: CallStmt
  getCall: CallExpr -> Ref_Pkg.Move
    getName: DottedName -> Ref_Pkg.Move
      getPrefix: Identifier S -> Reference.S
      getSuffix: Identifier Move -> Ref_Pkg.Move
    getSuffix: AssocList
      [0]: ParamAssoc
        getDesignator: Identifier By -> Ref_Pkg.Move.By
        getRExpr: IntLiteral 2
[5]: CallStmt
  getCall: CallExpr -> Ref_Pkg.Move
    getName: DottedName -> Ref_Pkg.Move
      getPrefix: Identifier Ref_Pkg -> Ref_Pkg
      getSuffix: Identifier Move -> Ref_Pkg.Move
    getSuffix: AssocList
      [0]: ParamAssoc
        getRExpr: Identifier S -> Reference.S
      [1]: ParamAssoc
        getRExpr: IntLiteral 3
```

The trees have the same shape. **What the prefix resolves to tells them apart**: a
package means an expanded name, an object means a prefixed view, where the prefix is
the first actual and is *not* in the `AssocList`. A component selection (`P.X`) is a
`DottedName` too, but its suffix resolves to a `ComponentDecl`.

### Control flow

```ada
if A = 1 then null; elsif A = 2 then A := 3; else A := 4; end if;
case A is when 1 | 2 => null; when others => A := 0; end case;
for I in Arr'Range loop Arr (I) := I; end loop;
while A < 10 loop A := A + 1; exit when A = 5; end loop;
```

```
[13]: IfStmt
  getCondExpr: RelationOp
    getLeft: Identifier A -> ...
    getOp: OpEq =
    getRight: IntLiteral 1
  getThenStmts: StmtList
    [0]: NullStmt
  getAlternatives: ElsifStmtPartList
    [0]: ElsifStmtPart
      getCondExpr: RelationOp  ...
      getStmts: StmtList  ...
  getElsePart: ElsePart
    getStmts: StmtList  ...
[14]: CaseStmt
  getExpr: Identifier A -> ...
  getAlternatives: CaseStmtAlternativeList
    [0]: CaseStmtAlternative
      getChoices: AlternativesList
        [0]: IntLiteral 1
        [1]: IntLiteral 2
      getStmts: StmtList
        [0]: NullStmt
    [1]: CaseStmtAlternative
      getChoices: AlternativesList
        [0]: OthersDesignator
      getStmts: StmtList  ...
[15]: ForLoopStmt
  getSpec: ForLoopSpec
    getVarDecl: ForLoopVarDecl
      getId: DefiningName
        getName: Identifier I
    getLoopType: IterTypeIn
    getIterExpr: AttributeRef
      getPrefix: Identifier Arr -> Reference.Arr
      getAttribute: Identifier Range
  getStmts: StmtList  ...
[16]: WhileLoopStmt
  getSpec: WhileLoopSpec
    getExpr: RelationOp  ...
  getStmts: StmtList
    [0]: AssignStmt  ...
    [1]: ExitStmt
      getCondExpr: RelationOp  ...
```

A plain `loop ... end loop` is a `LoopStmt` (with `getStmts`); `exit;` is an
`ExitStmt` with no condition. `ReturnStmt` has `getReturnExpr()`.
How control flows through each of these is specified in
[cfg-design.md](cfg-design.md).

### Blocks and exception handlers

```ada
declare Tmp : Integer := A; begin A := Tmp;
exception when E : Constraint_Error => raise; end;
```

```
[17]: DeclBlock
  getDecls: DeclarativePart
    getDecls: AdaNodeList
      [0]: ObjectDecl  ...  Identifier Tmp
  getStmts: HandledStmts
    getStmts: StmtList
      [0]: AssignStmt  ...
    getExceptions: AdaNodeList
      [0]: ExceptionHandler
        getExceptionName: DefiningName
          getName: Identifier E
        getHandledExceptions: AlternativesList
          [0]: Identifier Constraint_Error -> Standard.Constraint_Error
        getStmts: StmtList
          [0]: RaiseStmt
```

A block without `declare` is a `BeginBlock` (a `HandledStmts` directly, no
`getDecls`). A bare `raise;` has no
`getExceptionName()`.

## Expressions

### Calls, indexing, slicing and conversions all look alike

```ada
A := Twice (B);                       -- function call
A := Arr (2);                         -- indexing
Put_Line (Name (1 .. 2));             -- slicing
A := Integer (Ref_Pkg.Small'(3));     -- conversion of a qualified expression
```

```
getExpr: CallExpr -> Reference.Twice
  getName: Identifier Twice -> Reference.Twice
  getSuffix: AssocList  ...
getExpr: CallExpr -> Reference.Arr
  getName: Identifier Arr -> Reference.Arr
  getSuffix: AssocList
    [0]: ParamAssoc
      getRExpr: IntLiteral 2
getRExpr: CallExpr -> Reference.Name
  getName: Identifier Name -> Reference.Name
  getSuffix: BinOp
    getLeft: IntLiteral 1
    getOp: OpDoubleDot ..
    getRight: IntLiteral 2
getExpr: CallExpr -> Standard.Integer
  getName: Identifier Integer -> Standard.Integer
  getSuffix: AssocList
    [0]: ParamAssoc
      getRExpr: QualExpr -> Ref_Pkg.Small
        getPrefix: DottedName -> Ref_Pkg.Small
          ...
        getSuffix: ParenExpr
          getExpr: IntLiteral 3
```

**Every one is a `CallExpr`.** Tell them apart by what the name resolves to:

| The `CallExpr`'s name resolves to | It is |
| --- | --- |
| a subprogram (`SubpDecl`, `SubpBody`, `ExprFunction`, a renaming, ...) | a call |
| an object or formal (`ObjectDecl`, `ParamSpec`, `ComponentDecl`) | indexing, or slicing if the suffix is a range (`BinOp` with `OpDoubleDot`) |
| a type (`BaseTypeDecl`), *and the name is an `Identifier` or `DottedName`* | a type conversion |
| nothing | an unresolved call: an access-to-subprogram call, or a name the extractor could not resolve |

The hand-written way to ask "is this a call, and to what?" is
`DataFlow::getCallTarget(call)`. It also handles calls without parentheses and sees
through renamings.

**Trap: a qualified expression resolves to its type.** `Ref_Pkg.Small'(3)` above
resolves to `Ref_Pkg.Small`. Indexing one, `Arr'(3, 4) (1)`, is a `CallExpr` whose
*name* is a `QualExpr` resolving to the type `Arr`, and the `CallExpr` itself also
shows `-> Test.Arr`:

```
getExpr: CallExpr -> Test.Arr
  getName: QualExpr -> Test.Arr
    getPrefix: Identifier Arr -> Test.Arr
    getSuffix: Aggregate  ...
  getSuffix: AssocList
    [0]: ParamAssoc
      getRExpr: IntLiteral 1
```

That is why the table's conversion row requires the name to be a plain or dotted
name. Note also that `T'(X)` with a parenthesised operand has `getSuffix:
ParenExpr`.

### Attributes

```ada
A := Name'Length + Integer'Value ("4");
```

```
getExpr: BinOp
  getLeft: AttributeRef
    getPrefix: Identifier Name -> Reference.Name
    getAttribute: Identifier Length
    getArgs: AssocList
  getOp: OpPlus +
  getRight: CallExpr
    getName: AttributeRef
      getPrefix: Identifier Integer -> Standard.Integer
      getAttribute: Identifier Value
      getArgs: AssocList
    getSuffix: AssocList
      [0]: ParamAssoc
        getRExpr: StringLiteral "4"
```

**An attribute with an argument is a `CallExpr` around the `AttributeRef`**, whose
own `getArgs()` is empty; the argument is in the `CallExpr`'s suffix. The attribute
name is `getAttribute().getValue()` (case as written; compare with
`toLowerCase()`). Attributes do not resolve.

### Names: selection and dereference

```ada
P.X := Ptr.all.Y;
```

```
[10]: AssignStmt
  getDest: DottedName -> Ref_Pkg.Point.X
    getPrefix: Identifier P -> Reference.P
    getSuffix: Identifier X -> Ref_Pkg.Point.X
  getExpr: DottedName -> Ref_Pkg.Point.Y
    getPrefix: ExplicitDeref -> Reference.Ptr
      getPrefix: Identifier Ptr -> Reference.Ptr
    getSuffix: Identifier Y -> Ref_Pkg.Point.Y
```

- `Ptr.all` is an `ExplicitDeref`. It resolves to the *pointer* object, not to
  what it points at.
- A component selection resolves, as a whole and in its suffix, to the
  `ComponentDecl`. That declaration names both `X` and `Y`, so it carries both
  qualified names, and the tree shows the one each name denotes
  (see [Name resolution](#name-resolution)).
- An implicit dereference has no node at all. With `Q : Rec_Access`, `Q.Field` is
  just `DottedName -> Test.Rec.Field` with prefix `Identifier Q -> Test.Q`. You
  can't tell it from a selection on a record object without looking at `Q`'s type.

### Aggregates and allocators

```ada
P   : Ref_Pkg.Point := (X => 1, Y => 2);
Arr : Ref_Pkg.Int_Array (1 .. 3) := (others => 0);
Ptr : Ref_Pkg.Point_Access := new Ref_Pkg.Point'(P);
```

```
getDefaultExpr: Aggregate
  getAssocs: AssocList
    [0]: AggregateAssoc
      getDesignators: AlternativesList
        [0]: Identifier X -> Ref_Pkg.Point.X
      getRExpr: IntLiteral 1
    [1]: AggregateAssoc  ...  Y => 2
getDefaultExpr: Aggregate
  getAssocs: AssocList
    [0]: AggregateAssoc
      getDesignators: AlternativesList
        [0]: OthersDesignator
      getRExpr: IntLiteral 0
getDefaultExpr: Allocator
  getTypeOrExpr: QualExpr -> Ref_Pkg.Point
    getPrefix: DottedName -> Ref_Pkg.Point  ...
    getSuffix: ParenExpr
      getExpr: Identifier P -> Reference.P
```

A positional aggregate (`(1, 2)`) has `AggregateAssoc`s with empty designator lists.
`new Rec` without an initial value has `getTypeOrExpr: SubtypeIndication` (whose
`getName` resolves to `Rec`) instead of a `QualExpr`.

### Operators

```ada
Flag := A > 0 and then not Flag;
```

```
getExpr: BinOp
  getLeft: RelationOp
    getLeft: Identifier A -> ...
    getOp: OpGt >
    getRight: IntLiteral 0
  getOp: OpAndThen and then
  getRight: UnOp
    getOp: OpNot not
    getExpr: Identifier Flag -> Reference.Flag
```

- Arithmetic and logical operators are `BinOp`; comparisons are `RelationOp`, a
  subclass of `BinOp`. The operator is a node (`getOp()`, e.g. `OpAndThen`,
  `OpPlus`), not a string.
- **Short-circuit forms** (`and then`, `or else`) are `BinOp`s with `OpAndThen` /
  `OpOrElse`. The control-flow graph treats them specially (cfg-design.md).
- **Predefined operators do not resolve**: `A + 1` has no declaration of `"+"` to
  point at (D-026).
- A range `1 .. 3` is a `BinOp` with `OpDoubleDot`.

**Concatenation chains** are one `ConcatOp`, not nested `BinOp`s:

```ada
S : constant String := "a" & "b" & "c";
```

```
getDefaultExpr: ConcatOp
  getFirstOperand: StringLiteral "a"
  getOtherOperands: ConcatOperandList
    [0]: ConcatOperand
      getOperator: OpConcat &
      getOperand: StringLiteral "b"
    [1]: ConcatOperand
      getOperator: OpConcat &
      getOperand: StringLiteral "c"
```

**Membership tests** keep their alternatives in a list:

```ada
B : Boolean := Arr'(3, 4) (1) in 1 | 3;
```

```
getDefaultExpr: MembershipExpr
  getExpr: CallExpr -> Test.Arr  ...
  getOp: OpIn in
  getMembershipExprs: ExprAlternativesList
    [0]: IntLiteral 1
    [1]: IntLiteral 3
```

### Conditional expressions and parentheses

```ada
A := (if Flag then 1 else 2);
```

```
getExpr: ParenExpr
  getExpr: IfExpr
    getCondExpr: Identifier Flag -> Reference.Flag
    getThenExpr: IntLiteral 1
    getAlternatives: ElsifExprPartList
    getElseExpr: IntLiteral 2
```

**Parentheses are nodes** (`ParenExpr`), including the ones an `if` or `case`
expression must have. Look through them (`.(ParenExpr).getExpr()`) when matching
an expression's shape. A `case` expression is a `CaseExpr` with
`CaseExprAlternative`s.

### Literals

`IntLiteral`, `RealLiteral`, `StringLiteral` (value with quotes, `"abc"`),
`CharLiteral` (value with apostrophes, `'a'`) and `NullLiteral` (value `null`).
Enumeration literals such as
`True` and `False` are `Identifier`s that resolve to the literal's declaration
(`-> Standard.Boolean.False`).

## Name resolution

`Name.getReferencedDecl()` returns what Libadalang resolved a name to (`ada_xref`).
What to expect:

- **It resolves to a declaration node**, a `BasicDecl`: `ObjectDecl`, `ParamSpec`,
  `SubpDecl`, `SubpBody`, `ComponentDecl`, `EnumLiteralDecl`, ...
- **Spec or body: it depends where the name is.** In the fixture, a call to
  `Ref_Pkg.Move` from outside the package, and its named designator `By`, resolve to
  the spec's `SubpDecl` and its `ParamSpec`. Inside the body, the formals `S` and
  `By` resolve to the body's own `ParamSpec`s, and `end Move` resolves to the
  `SubpBody`. So one subprogram's parameter is two declaration nodes. Compare across
  the pair with `getBody()` / `getDeclaration()`, not by node identity.
- **Runtime entities resolve** when a GNAT runtime was found at extraction:
  `Put_Line` resolves into `a-textio.ads`, a predefined pseudo-source (D-026). Match
  them with `hasQualifiedName("Ada.Text_IO.Put_Line")`, after `getUltimateDecl()`
  to see through renamings.
- **A declaration of several names has one qualified name per name.** For
  `A, B : Integer`, `getQualifiedName()` gives both `Reference.A` and `Reference.B`,
  and `hasQualifiedName` matches either. The declaration is one node, so a reference
  to `A` resolves to the same `ObjectDecl` as a reference to `B`, and
  `n.getReferencedDecl().hasQualifiedName("Reference.B")` holds for both. When it
  matters which name, compare the name's text too, or use `Name.denotesSameEntityAs`.
  (Before the 2026-10-03 extractor change, such declarations had no qualified name.)
- **What does not resolve:** predefined operators, attributes, pragma and aspect
  identifiers, and names the extractor's project setup could not see (see the user
  guide, "Project discovery and name-resolution quality").
- **Qualified expressions and their indexing resolve to the type**, and an
  `ExplicitDeref` to the pointer object (above).
- **Several names can resolve to one declaration**: the `end` name of a body, a
  named association's designator, a pragma argument. Filter by position in the tree
  if you count uses.

## Constructs not shown

Tasks and protected objects (`SingleTaskDecl`, `TaskBody`, `ProtectedBody`,
`EntryBody`, `AcceptStmt`, `SelectStmt`), generics' own declarations
(`GenericSubpDecl`, `GenericPackageDecl` and their formals), separate bodies
(`SubpBodyStub`), representation clauses, `goto` and labels, extended returns,
quantified expressions, and declare expressions. Print a small example with the
tools above. [cfg-design.md](cfg-design.md) has the shapes of the statements it
covers, with snippets.
