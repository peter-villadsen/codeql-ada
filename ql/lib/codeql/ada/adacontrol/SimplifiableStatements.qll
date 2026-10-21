/**
 * AdaControl rule `Simplifiable_Statements`: statements that can be removed or
 * simplified without changing the meaning of the program (`docs/adacontrol.md`).
 * `simplifiable(s, subrule)` holds for each subrule that applies to `s`.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.TypeCategories

module SimplifiableStatements {
  /** Gets `e` without the parentheses around it. */
  private Raw::Expr unparen(Raw::Expr e) {
    if e instanceof Raw::ParenExpr then result = unparen(e.(Raw::ParenExpr).getExpr()) else result = e
  }

  /** Holds if `e` is the literal `True` (`value = true`) or `False`, possibly negated or parenthesized. */
  predicate isStaticBoolean(Raw::Expr e, boolean value) {
    exists(Raw::Name n | n = unparen(e) |
      n.getReferencedDecl().hasQualifiedName(["Standard.True", "Standard.Boolean.True"]) and value = true
      or
      n.getReferencedDecl().hasQualifiedName(["Standard.False", "Standard.Boolean.False"]) and value = false
      or
      not exists(n.getReferencedDecl()) and
      n instanceof Raw::Identifier and
      (
        n.(Raw::Identifier).getValue().toLowerCase() = "true" and value = true
        or
        n.(Raw::Identifier).getValue().toLowerCase() = "false" and value = false
      )
    )
    or
    exists(Raw::UnOp u | u = unparen(e) and u.getOp() instanceof Raw::OpNot |
      isStaticBoolean(u.getExpr(), value.booleanNot())
    )
  }

  /** Gets the value of `e` if it is an integer literal, possibly negated. */
  private int literal(Raw::Expr e) {
    result = unparen(e).(Raw::IntLiteral).getValue().replaceAll("_", "").toInt()
    or
    unparen(e).(Raw::UnOp).getOp() instanceof Raw::OpMinus and
    result = -literal(unparen(e).(Raw::UnOp).getExpr())
  }

  /** Holds if `s` is a statement after which control never continues: `return`, `requeue`, `goto`, an unconditional `exit`, `raise`. */
  private predicate isBreaking(Raw::Stmt s) {
    s instanceof Raw::ReturnStmt or
    s instanceof Raw::ExtendedReturnStmt or
    s instanceof Raw::RequeueStmt or
    s instanceof Raw::GotoStmt or
    s instanceof Raw::RaiseStmt or
    s instanceof Raw::ExitStmt and
    (not exists(s.(Raw::ExitStmt).getCondExpr()) or isStaticBoolean(s.(Raw::ExitStmt).getCondExpr(), true))
  }

  /** Gets the last statement of `list`, pragmas aside. */
  private Raw::Stmt lastStmt(Raw::StmtList list) {
    result = max(Raw::Stmt s, int i | s = list.getChild(i) and not s instanceof Raw::Label | s order by i)
  }

  /** Gets the kind of breaking statement `s`, to compare two paths. */
  private string breakKind(Raw::Stmt s) {
    isBreaking(s) and result = s.getAPrimaryQlClass()
  }

  /** Holds if `list` holds only `null` statements. */
  private predicate onlyNull(Raw::StmtList list) {
    exists(Raw::NullStmt n | n = list.getChild(_)) and
    not exists(Raw::AdaNode s | s = list.getChild(_) |
      not s instanceof Raw::NullStmt and not s instanceof Raw::PragmaNode
    )
  }

  /** Gets the only statement of `list`, pragmas aside. */
  private Raw::Stmt onlyStmt(Raw::StmtList list) {
    result = list.getChild(_) and strictcount(Raw::Stmt s | s = list.getChild(_)) = 1
  }

  /** Gets the conditions of `if` statement `i`: its own and those of its `elsif` parts, with their position. */
  private Raw::Expr condition(Raw::IfStmt i, int pos) {
    pos = -1 and result = i.getCondExpr()
    or
    exists(Raw::ElsifStmtPart e | e = i.getAlternatives().getChild(pos) | result = e.getCondExpr())
  }

  /** Holds if `e` and `f` are the same expression, compared as source-text-like structure. */
  private predicate sameExpr(Raw::Expr e, Raw::Expr f) {
    e != f and
    e.getAPrimaryQlClass() = f.getAPrimaryQlClass() and
    e.toString() = f.toString() and
    (
      e.(Raw::Name).denotesSameEntityAs(f)
      or
      e.(Raw::IntLiteral).getValue() = f.(Raw::IntLiteral).getValue()
      or
      e.(Raw::RealLiteral).getValue() = f.(Raw::RealLiteral).getValue()
      or
      exists(Raw::BinOp a, Raw::BinOp b | a = e and b = f |
        a.getOp().getAPrimaryQlClass() = b.getOp().getAPrimaryQlClass() and
        sameExpr(a.getLeft(), b.getLeft()) and
        sameExpr(a.getRight(), b.getRight())
      )
      or
      exists(Raw::UnOp a, Raw::UnOp b | a = e and b = f |
        a.getOp().getAPrimaryQlClass() = b.getOp().getAPrimaryQlClass() and
        sameExpr(a.getExpr(), b.getExpr())
      )
      or
      sameExpr(e.(Raw::ParenExpr).getExpr(), f.(Raw::ParenExpr).getExpr())
    )
  }

  /** Gets the variable of the loop parameter of `for` loop `l`. */
  Raw::ForLoopVarDecl loopVar(Raw::ForLoopStmt l) {
    result = l.getSpec().(Raw::ForLoopSpec).getVarDecl()
  }

  /** Gets a use of the loop parameter of `l`. */
  private Raw::Identifier aUseOf(Raw::ForLoopStmt l) {
    result.getReferencedDecl() = loopVar(l) and
    not result.getParent() instanceof Raw::DefiningName
  }

  /** Holds if `use`, a use of a loop parameter, is the only index of an indexing of object `arr` (`A (I)`). */
  private predicate indexes(Raw::Identifier use, Raw::BasicDecl arr) {
    exists(Raw::CallExpr c, Raw::AssocList args |
      args = c.getSuffix() and
      use = args.getChild(0).(Raw::ParamAssoc).getRExpr() and
      not exists(args.getChild(1)) and
      arr = c.getName().getReferencedDecl() and
      (arr instanceof Raw::ObjectDecl or arr instanceof Raw::ParamSpec)
    )
  }

  /** Gets the prefix of `X'Range`, or of `X'First .. X'Last`, the range of `for` loop `l`, as a declaration. */
  private Raw::BasicDecl rangeOf(Raw::ForLoopStmt l) {
    exists(Raw::AdaNode iter | iter = l.getSpec().(Raw::ForLoopSpec).getIterExpr() |
      iter.(Raw::AttributeRef).getAttribute().getValue().toLowerCase() = "range" and
      result = iter.(Raw::AttributeRef).getPrefix().getReferencedDecl()
      or
      exists(Raw::AttributeRef first, Raw::AttributeRef last |
        first = iter.(Raw::BinOp).getLeft() and
        last = iter.(Raw::BinOp).getRight() and
        first.getAttribute().getValue().toLowerCase() = "first" and
        last.getAttribute().getValue().toLowerCase() = "last" and
        result = first.getPrefix().getReferencedDecl() and
        result = last.getPrefix().getReferencedDecl()
      )
    )
  }

  /**
   * `for_in_for_for_of`: every use of the parameter of `for ... in` loop `l` indexes the
   * same one-dimensional array `arr`; with `fullRange`, the loop covers `arr`'s whole range.
   */
  predicate forInForForOf(Raw::ForLoopStmt l, Raw::BasicDecl arr, boolean fullRange) {
    l.getSpec().(Raw::ForLoopSpec).getLoopType() instanceof Raw::IterTypeIn and
    exists(aUseOf(l)) and
    forex(Raw::Identifier use | use = aUseOf(l) | indexes(use, arr)) and
    if rangeOf(l) = arr then fullRange = true else fullRange = false
  }

  /** Holds if `e` is the loop parameter of `l`, possibly plus or minus an integer literal. */
  private predicate isShiftedIndex(Raw::Expr e, Raw::ForLoopStmt l) {
    unparen(e) = aUseOf(l)
    or
    exists(Raw::BinOp b | b = unparen(e) |
      (b.getOp() instanceof Raw::OpPlus or b.getOp() instanceof Raw::OpMinus) and
      b.getLeft() = aUseOf(l) and
      exists(literal(b.getRight()))
    )
  }

  /** Holds if `e` is an indexing `A (I + k)` by the parameter of loop `l`. */
  private predicate isShiftedIndexing(Raw::Expr e, Raw::ForLoopStmt l) {
    exists(Raw::CallExpr c, Raw::AssocList args | c = unparen(e) and args = c.getSuffix() |
      isShiftedIndex(args.getChild(0).(Raw::ParamAssoc).getRExpr(), l) and
      not exists(args.getChild(1)) and
      c.getName().getReferencedDecl() instanceof Raw::ObjectDecl
    )
  }

  /**
   * `for_for_slice`: the body of `for` loop `l` holds only assignments to an element of an
   * array indexed by the loop parameter (`A (I + k)`), of an element indexed the same way
   * or of a value that does not depend on the parameter: a slice or aggregate assignment.
   */
  predicate forForSlice(Raw::ForLoopStmt l) {
    l.getSpec().(Raw::ForLoopSpec).getLoopType() instanceof Raw::IterTypeIn and
    exists(Raw::AssignStmt a | a = l.getStmts().getChild(_)) and
    not exists(Raw::AdaNode s | s = l.getStmts().getChild(_) |
      not s instanceof Raw::PragmaNode and not isSliceAssignment(s, l)
    )
  }

  /** Holds if `a` assigns `A (I + k)` a value `B (I + m)`, or one that does not depend on `I`. */
  private predicate isSliceAssignment(Raw::AssignStmt a, Raw::ForLoopStmt l) {
    a.getParent() = l.getStmts() and
    isShiftedIndexing(a.getDest(), l) and
    (
      isShiftedIndexing(a.getExpr(), l)
      or
      not exists(Raw::Identifier use | use = aUseOf(l) and use.getParent*() = a.getExpr())
    )
  }

  /** Holds if handler `h` holds only `raise;`. */
  private predicate isTrivialHandler(Raw::ExceptionHandler h) {
    onlyStmt(h.getStmts()) instanceof Raw::RaiseStmt and
    not exists(onlyStmt(h.getStmts()).(Raw::RaiseStmt).getExceptionName())
  }

  /** `handler`: `h` only re-raises, and no non-trivial `when others` handler follows it. */
  predicate trivialHandler(Raw::ExceptionHandler h) {
    isTrivialHandler(h) and
    not exists(Raw::ExceptionHandler others |
      others.getParent() = h.getParent() and
      others.getHandledExceptions().getChild(_) instanceof Raw::OthersDesignator and
      not isTrivialHandler(others)
    )
  }

  /** Holds if `e` names a variable (or parameter) of a discrete type. */
  private predicate isDiscreteVariable(Raw::Name e, Raw::BasicDecl v) {
    v = e.getReferencedDecl() and
    (v instanceof Raw::ObjectDecl or v instanceof Raw::ParamSpec) and
    exists(string c | c = TypeCategories::category(e.getType(), false) | c = ["()", "range", "mod"])
  }

  /** Holds if `e` is a static value: a literal, an enumeration literal, a named number. */
  private predicate isStaticValue(Raw::Expr e) {
    unparen(e) instanceof Raw::NumLiteral or
    unparen(e) instanceof Raw::CharLiteral or
    exists(literal(e)) or
    unparen(e).(Raw::Name).getReferencedDecl() instanceof Raw::EnumLiteralDecl or
    unparen(e).(Raw::Name).getReferencedDecl() instanceof Raw::NumberDecl
  }

  /** Holds if condition `e` only compares variable `v` with static values (`=`, `<`, `in`, ...), joined by `and`/`or`. */
  private predicate comparesOnly(Raw::Expr e, Raw::BasicDecl v) {
    exists(Raw::BinOp b | b = unparen(e) |
      (
        b.getOp() instanceof Raw::OpAnd or b.getOp() instanceof Raw::OpOr or
        b.getOp() instanceof Raw::OpAndThen or b.getOp() instanceof Raw::OpOrElse
      ) and
      comparesOnly(b.getLeft(), v) and
      comparesOnly(b.getRight(), v)
      or
      b instanceof Raw::RelationOp and
      isDiscreteVariable(b.getLeft(), v) and
      isStaticValue(b.getRight())
    )
    or
    exists(Raw::MembershipExpr m | m = unparen(e) |
      isDiscreteVariable(m.getExpr(), v) and
      forex(Raw::Expr alt | alt = m.getMembershipExprs().getChild(_) |
        isStaticValue(alt)
        or
        isStaticValue(alt.(Raw::BinOp).getLeft()) and isStaticValue(alt.(Raw::BinOp).getRight())
      )
    )
  }

  /**
   * Holds if the condition of `while` loop `l` compares variable `v` (`<`, `<=`, `>`, `>=`,
   * `/=`) with an expression; `up` says whether `v` must increase to end the loop.
   */
  private predicate whileComparison(Raw::WhileLoopStmt l, Raw::BasicDecl v, boolean up) {
    exists(Raw::BinOp b, Raw::Op op | b = unparen(l.getSpec().(Raw::WhileLoopSpec).getExpr()) and op = b.getOp() |
      v = b.getLeft().(Raw::Identifier).getReferencedDecl() and
      (
        (op instanceof Raw::OpLt or op instanceof Raw::OpLte) and up = true
        or
        (op instanceof Raw::OpGt or op instanceof Raw::OpGte) and up = false
        or
        op instanceof Raw::OpNeq and up = [true, false]
      )
      or
      v = b.getRight().(Raw::Identifier).getReferencedDecl() and
      (
        (op instanceof Raw::OpGt or op instanceof Raw::OpGte) and up = true
        or
        (op instanceof Raw::OpLt or op instanceof Raw::OpLte) and up = false
        or
        op instanceof Raw::OpNeq and up = [true, false]
      )
    ) and
    (v instanceof Raw::ObjectDecl or v instanceof Raw::ParamSpec)
  }

  /** Holds if `a` assigns `v` its successor (`up`) or predecessor: `V := V + 1`, `V := T'Succ (V)`. */
  private predicate isStep(Raw::AssignStmt a, Raw::BasicDecl v, boolean up) {
    a.getDest().(Raw::Identifier).getReferencedDecl() = v and
    exists(Raw::Expr e | e = unparen(a.getExpr()) |
      exists(Raw::BinOp b | b = e and b.getLeft().(Raw::Identifier).getReferencedDecl() = v and literal(b.getRight()) = 1 |
        b.getOp() instanceof Raw::OpPlus and up = true
        or
        b.getOp() instanceof Raw::OpMinus and up = false
      )
      or
      exists(Raw::AttributeRef r, string attr |
        r = e.(Raw::CallExpr).getName() and
        attr = r.getAttribute().getValue().toLowerCase() and
        e.(Raw::CallExpr).getSuffix().(Raw::AssocList).getChild(0).(Raw::ParamAssoc).getRExpr().(Raw::Identifier).getReferencedDecl() = v
      |
        attr = "succ" and up = true
        or
        attr = "pred" and up = false
      )
    )
  }

  /** Holds if an `exit` statement in `l` leaves `l`. */
  private predicate hasExit(Raw::BaseLoopStmt l, Raw::ExitStmt except) {
    exists(Raw::ExitStmt e | e.getParent+() = l and e != except |
      exists(Raw::NamedStmtDecl d | d = e.getLoopName().getReferencedDecl() |
        d.getParent().(Raw::NamedStmt).getStmt() = l
      )
      or
      not exists(e.getLoopName()) and
      not exists(Raw::BaseLoopStmt inner | e.getParent+() = inner and inner.getParent+() = l)
    )
  }

  /**
   * `while_for_for`: `while` loop `l` steps variable `v` once, unconditionally (a statement
   * of the loop body itself, not of a branch in it), towards ending its condition,
   * and passes it to no `out` or `in out` parameter; with `noExit`, no `exit` leaves it.
   */
  predicate whileForFor(Raw::WhileLoopStmt l, Raw::BasicDecl v, boolean noExit) {
    exists(boolean up |
      whileComparison(l, v, up) and
      strictcount(Raw::AssignStmt a | a.getParent+() = l and a.getDest().(Raw::Identifier).getReferencedDecl() = v) = 1 and
      // stepped on every iteration: directly in the loop's statements, not in a branch
      exists(Raw::AssignStmt a | a.getParent() = l.getStmts() and isStep(a, v, up))
    ) and
    not exists(Call c, Parameter p, Raw::Identifier arg |
      c.getParent+() = l and
      arg = c.getArgumentFor(p) and
      p.isOut() and
      arg.getReferencedDecl() = v
    ) and
    (noExit = false or noExit = true and not hasExit(l, _))
  }

  /** Holds if statement `s` is preceded, in its list, by a breaking statement. */
  private predicate afterBreaking(Raw::Stmt s) {
    exists(Raw::StmtList list, int i, int j |
      s = list.getChild(i) and
      j < i and
      isBreaking(list.getChild(j)) and
      // a label makes the statement after it reachable (a goto may jump to it)
      not exists(int k | k in [j + 1 .. i] and list.getChild(k) instanceof Raw::Label)
    )
  }

  /**
   * Holds if `s` is the first statement after a `return`, `requeue`, `goto`, `raise` or
   * unconditional `exit` in its list (the part of `dead` that `ada/unreachable-statement`
   * also finds, along the control-flow graph).
   */
  predicate deadAfterJump(Raw::Stmt s) {
    afterBreaking(s) and
    not exists(Raw::StmtList list, int i | s = list.getChild(i) and afterBreaking(list.getChild(i - 1)))
  }

  /** Holds if `s` is of the kind AdaControl's `Simplifiable_Statements` names `subrule`. */
  predicate simplifiable(Raw::AdaNode s, string subrule) {
    // block: no name, no declarations, no handlers
    exists(Raw::HandledStmts hs |
      hs = [s.(Raw::BeginBlock).getStmts(), s.(Raw::DeclBlock).getStmts()] and
      not s.getParent() instanceof Raw::NamedStmt and
      not exists(hs.getExceptions().getChild(_)) and
      not exists(Raw::AdaNode d | d = s.(Raw::DeclBlock).getDecls().getDecls().getChild(_)) and
      subrule = "block"
    )
    or
    // dead code
    (
      deadAfterJump(s)
      or
      isStaticBoolean(s.(Raw::WhileLoopStmt).getSpec().(Raw::WhileLoopSpec).getExpr(), false)
      or
      isStaticBoolean(s.(Raw::IfStmt).getCondExpr(), false)
      or
      isStaticBoolean(s.(Raw::ElsifStmtPart).getCondExpr(), false)
      or
      // an elsif or else after a condition that is True
      exists(Raw::IfStmt i, int pos | isStaticBoolean(condition(i, pos), true) |
        exists(int k | s = i.getAlternatives().getChild(k) and k > pos)
        or
        s = i.getElsePart()
      )
      or
      // an elsif with the condition of an earlier path
      exists(Raw::IfStmt i, int pos, int k |
        s = i.getAlternatives().getChild(k) and
        pos < k and
        sameExpr(condition(i, pos), s.(Raw::ElsifStmtPart).getCondExpr())
      )
      or
      // a for loop over a static empty range
      exists(Raw::BinOp r |
        r = s.(Raw::ForLoopStmt).getSpec().(Raw::ForLoopSpec).getIterExpr() and
        r.getOp() instanceof Raw::OpDoubleDot and
        literal(r.getLeft()) > literal(r.getRight())
      )
    ) and
    subrule = "dead"
    or
    forInForForOf(s, _, _) and subrule = "for_in_for_for_of"
    or
    forForSlice(s) and subrule = "for_for_slice"
    or
    trivialHandler(s) and subrule = "handler"
    or
    onlyNull(s.(Raw::IfStmt).getElsePart().getStmts()) and subrule = "if"
    or
    exists(Raw::IfStmt i, Raw::BasicDecl v | i = s |
      exists(i.getAlternatives().getChild(_)) and
      forex(Raw::Expr c | c = condition(i, _) | comparesOnly(c, v))
    ) and
    subrule = "if_for_case"
    or
    exists(Raw::IfStmt i | i = s |
      exists(i.getElsePart()) and
      not exists(i.getAlternatives().getChild(_)) and
      (
        unparen(i.getCondExpr()).(Raw::UnOp).getOp() instanceof Raw::OpNot or
        unparen(i.getCondExpr()).(Raw::BinOp).getOp() instanceof Raw::OpNeq
      )
    ) and
    subrule = "if_not"
    or
    isStaticBoolean(s.(Raw::WhileLoopStmt).getSpec().(Raw::WhileLoopSpec).getExpr(), true) and
    subrule = "loop"
    or
    exists(Raw::LoopStmt l, Raw::ExitStmt e | l = s |
      e = l.getStmts().getChild(0) and
      (
        not exists(e.getLoopName())
        or
        e.getLoopName().getReferencedDecl().getParent().(Raw::NamedStmt).getStmt() = l
      ) and
      (
        subrule = "loop_for_while"
        or
        not hasExit(l, e) and subrule = "no_exit loop_for_while"
      )
    )
    or
    exists(Raw::IfStmt i, Raw::Stmt thenLast, Raw::Stmt elseLast | i = s |
      not exists(i.getAlternatives().getChild(_)) and
      thenLast = lastStmt(i.getThenStmts()) and
      elseLast = lastStmt(i.getElsePart().getStmts()) and
      (isBreaking(thenLast) or isBreaking(elseLast)) and
      not breakKind(thenLast) = breakKind(elseLast)
    ) and
    subrule = "nested_path"
    or
    // a null statement among other statements, and not labelled
    exists(Raw::StmtList list, int i |
      s = list.getChild(i) and
      s instanceof Raw::NullStmt and
      exists(Raw::Stmt other | other = list.getChild(_) and not other instanceof Raw::NullStmt and not other instanceof Raw::Label) and
      not list.getChild(i - 1) instanceof Raw::Label
    ) and
    subrule = "null"
    or
    (
      isStaticBoolean(s.(Raw::IfStmt).getCondExpr(), true) or
      isStaticBoolean(s.(Raw::ElsifStmtPart).getCondExpr(), true)
    ) and
    subrule = "true_if"
    or
    exists(Raw::IfStmt i, Raw::Stmt t, Raw::Stmt e, boolean b | i = s |
      not exists(i.getAlternatives().getChild(_)) and
      t = onlyStmt(i.getThenStmts()) and
      e = onlyStmt(i.getElsePart().getStmts()) and
      (
        t.(Raw::AssignStmt).getDest().(Raw::Name).denotesSameEntityAs(e.(Raw::AssignStmt).getDest()) and
        isStaticBoolean(t.(Raw::AssignStmt).getExpr(), b) and
        isStaticBoolean(e.(Raw::AssignStmt).getExpr(), b.booleanNot())
        or
        isStaticBoolean(t.(Raw::ReturnStmt).getReturnExpr(), b) and
        isStaticBoolean(e.(Raw::ReturnStmt).getReturnExpr(), b.booleanNot())
      )
    ) and
    subrule = "unnecessary_if"
    or
    exists(boolean noExit | whileForFor(s, _, noExit) |
      noExit = false and subrule = "while_for_for"
      or
      noExit = true and subrule = "no_exit while_for_for"
    )
  }
}
