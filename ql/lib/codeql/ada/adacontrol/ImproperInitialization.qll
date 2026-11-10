/**
 * AdaControl rule `Improper_Initialization`: local variables and `out` parameters
 * should get their value before the "active" part of a subprogram, its first
 * non-trivial statement (`docs/adacontrol.md`).
 *
 * This is the rule's design pattern, not data flow. The statements of a subprogram
 * body up to the first non-trivial one are its *initial sequence*; trivial are `null`,
 * assignments, procedure calls, `return`, `raise`, and `if`, `case` and extended
 * `return` statements made only of trivial statements. A *target* (a local variable
 * or an `out` parameter) is assigned by an assignment to it as a whole, by passing it
 * for an `out` parameter (not `in out`), or by an `if` (with an `else`) or a `case`
 * whose every branch assigns it.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.Assignments
private import codeql.ada.adacontrol.DirectlyAccessedGlobals
private import codeql.ada.adacontrol.Places
private import codeql.ada.adacontrol.TypeCategories
private import codeql.ada.adacontrol.ObjectDeclarations

module ImproperInitialization {
  /* --- statements ------------------------------------------------------------ */

  /** Gets the `i`th statement (0-based) of the statements of subprogram body `b`. */
  Raw::AdaNode bodyStmt(Raw::SubpBody b, int i) { result = b.getStmts().getStmts().getChild(i) }

  /**
   * Gets the `k`th branch of compound statement `s`: for an `if`, the `then` part (0),
   * the `elsif` parts in order, then the `else` part; for a `case`, its alternatives;
   * for an extended `return`, its statements (0).
   */
  Raw::StmtList branch(Raw::AdaNode s, int k) {
    exists(Raw::IfStmt i | i = s |
      k = 0 and result = i.getThenStmts()
      or
      result = i.getAlternatives().getChild(k - 1).(Raw::ElsifStmtPart).getStmts()
      or
      k = count(i.getAlternatives().getChild(_)) + 1 and result = i.getElsePart().getStmts()
    )
    or
    result = s.(Raw::CaseStmt).getAlternatives().getChild(k).(Raw::CaseStmtAlternative).getStmts()
    or
    k = 0 and result = s.(Raw::ExtendedReturnStmt).getStmts().getStmts()
  }

  /** Gets the number of branches of `if` or `case` statement `s`, `else` included. */
  private int branchCount(Raw::AdaNode s) {
    (s instanceof Raw::IfStmt or s instanceof Raw::CaseStmt) and
    result = count(int k | exists(branch(s, k)))
  }

  /** Holds if `s` is a statement of a statement list that is not trivial. Pragmas are not statements. */
  predicate isNonTrivial(Raw::AdaNode s) {
    s.getParent() instanceof Raw::StmtList and
    not s instanceof Raw::PragmaNode and
    (
      not s instanceof Raw::NullStmt and
      not s instanceof Raw::AssignStmt and
      not s instanceof Raw::CallStmt and
      not s instanceof Raw::ReturnStmt and
      not s instanceof Raw::RaiseStmt and
      not s instanceof Raw::IfStmt and
      not s instanceof Raw::CaseStmt and
      not s instanceof Raw::ExtendedReturnStmt
      or
      isNonTrivial(branch(s, _).getChild(_))
    )
  }

  /**
   * Gets the index of the first non-trivial statement of body `b`, or the number of
   * its statements when all are trivial: the initial sequence is the statements
   * before it.
   */
  int initialEnd(Raw::SubpBody b) {
    result = min(int i | isNonTrivial(bodyStmt(b, i)))
    or
    not isNonTrivial(bodyStmt(b, _)) and result = count(bodyStmt(b, _))
  }

  /** Gets the first non-trivial statement of body `b`, if it has one. */
  Raw::AdaNode firstNonTrivial(Raw::SubpBody b) { result = bodyStmt(b, initialEnd(b)) }

  /** Holds if `n` is in the initial sequence of body `b`. */
  predicate inInitialSequence(Raw::AdaNode n, Raw::SubpBody b) {
    exists(int i | n.getParent*() = bodyStmt(b, i) and i < initialEnd(b))
  }

  /* --- targets --------------------------------------------------------------- */

  /** Holds if `v` is a variable declared directly in the declarations of subprogram body `b`. */
  private predicate isLocal(Variable v, Raw::SubpBody b) {
    Places::declarativePart(v.getDeclaration()) = b.getDecls() and
    not v.isConstant() and
    not v.isRenaming()
  }

  /** Holds if `p` is an `out` parameter of the subprogram whose body is `b`. */
  private predicate isOutParameter(Parameter p, Raw::SubpBody b) {
    p.getMode() = "out" and p.getSubprogram().getBody() = b
  }

  /**
   * Holds if `target` is a target of body `b`: a local variable (`kind` = `variable`)
   * or an `out` parameter (`out_parameter`).
   */
  predicate isTarget(Raw::Name target, Raw::SubpBody b, string kind) {
    isLocal(target, b) and kind = "variable"
    or
    isOutParameter(target, b) and kind = "out_parameter"
  }

  /** Gets the name of target `target`. */
  string targetName(Raw::Name target) {
    result = target.(Variable).getName() or result = target.(Parameter).getName()
  }

  /** Gets the type of target `target`. */
  Type targetType(Raw::Name target) {
    result = target.(Variable).getType() or result = target.(Parameter).getType()
  }

  /**
   * Holds if target `target` is skipped without AdaControl's extras: of an access type
   * or one holding an access value (`access`, initialized by the compiler), or of a
   * limited type (`limited`, which cannot be assigned as a whole).
   */
  predicate isSkipped(Raw::Name target, string extra) {
    Assignments::holdsAccess(targetType(target)) and extra = "access"
    or
    Assignments::isLimited(targetType(target)) and extra = "limited"
  }

  /**
   * Holds if `target` is aliased: its `'Access`, `'Unchecked_Access`,
   * `'Unrestricted_Access` or `'Address` is taken, so it may be assigned through it;
   * or it is a variable with an address clause, or imported.
   */
  predicate isAliased(Raw::Name target) {
    exists(Raw::AttributeRef a |
      a.getPrefix() = anAccess(target) or unresolvedName(a.getPrefix(), target)
    |
      a.getAttribute().getText().toLowerCase() =
        ["access", "unchecked_access", "unrestricted_access", "address"]
    )
    or
    // an overlay (`with Address => ...`) or an imported object
    exists(Raw::ObjectDecl d | d = target.(Variable).getDeclaration() |
      ObjectDeclarations::hasAddress(d) or
      ObjectDeclarations::hasAspectOrPragma(d, "import")
    )
  }

  /**
   * Holds if objects of type `t` are known to have no default value: a scalar type
   * (enumeration, integer, real), or an array of one. Records, private and tagged
   * types, and types whose definition is not in the database, may be initialized by
   * default (component defaults, `Initialize`, an empty container), which AdaControl
   * does not see either.
   */
  predicate hasNoDefault(Type t) {
    TypeCategories::category(t, true) = ["()", "range", "mod", "digits", "delta"]
    or
    TypeCategories::category(t, true) = "array" and
    hasNoDefault(namedType(TypeCategories::ultimateType(t)
            .getDefinition()
            .(Raw::ArrayTypeDef)
            .getComponentType()
            .getTypeExpr()))
  }

  /** Gets an identifier that names `target`. */
  Raw::Identifier anAccess(Raw::Name target) {
    isTarget(target, _, _) and
    (result = target.(Variable).getAnAccess() or result = target.(Parameter).getAnAccess())
  }

  /**
   * Holds if identifier `n`, in body `b`, does not resolve but is spelled like
   * target `target` of `b`: the extractor leaves the target of an assignment whose
   * value does not resolve unresolved too. Selectors, named-association designators
   * and attribute designators are not names of targets.
   */
  private predicate unresolvedName(Raw::Identifier n, Raw::Name target) {
    exists(Raw::SubpBody b |
      isTarget(target, b, _) and
      n.getParent+() = b and
      not exists(n.getReferencedDecl()) and
      n.getText().toLowerCase() = targetName(target).toLowerCase() and
      not n = any(Raw::DottedName d).getSuffix() and
      not n = any(Raw::ParamAssoc a).getDesignator() and
      not n = any(Raw::AttributeRef a).getAttribute()
    )
  }

  /**
   * Holds if `n` names `target` and gets its value there: as a whole, as an
   * assignment's target or an `out` actual of a call; or, with `parts`,
   * also a part of it (a component, an element, a slice) assigned or passed for an
   * `out` parameter. An unresolved name spelled like the target counts.
   */
  private predicate assignedAt(Raw::Identifier n, Raw::Name target, boolean parts) {
    (n = anAccess(target) or unresolvedName(n, target)) and
    (
      n = any(Raw::AssignStmt s).getDest() and parts = [false, true]
      or
      exists(Call c, Parameter p | n = c.getArgumentFor(p) and p.getMode() = "out") and
      parts = [false, true]
      or
      // an actual of a call that does not resolve, or of an attribute
      // (`'Asm_Output`), may be an output: it is not known not to be
      parts = [false, true] and
      exists(Raw::ParamAssoc a | n = a.getRExpr() |
        a.getParent().getParent().(Raw::AttributeRef).getAttribute().getText().toLowerCase() =
          "asm_output"
        or
        exists(Raw::CallExpr c |
          a.getParent() = c.getSuffix() and
          not c instanceof Call and
          not exists(c.getName().getReferencedDecl())
        )
      )
      or
      parts = true and
      DirectlyAccessedGlobals::written(n, false) and
      not DirectlyAccessedGlobals::written(n, true)
    )
  }

  /** Holds if branches `k` and after of `s`, an `if` or a `case`, each assign `target`. */
  private predicate branchesAssign(Raw::AdaNode s, int k, Raw::Name target, boolean parts) {
    exists(int last | last = branchCount(s) - 1 |
      k = last and listAssigns(branch(s, k), target, parts)
      or
      k < last and listAssigns(branch(s, k), target, parts) and branchesAssign(s, k + 1, target, parts)
    )
  }

  /**
   * Holds if a statement of `list` assigns `target`, or `list` ends with a `return`,
   * `raise` or `goto`: control does not leave it with `target` unassigned (a `return`
   * before an `out` parameter is assigned is `returnBeforeAssign`).
   */
  private predicate listAssigns(Raw::StmtList list, Raw::Name target, boolean parts) {
    assigns(list.getChild(_), target, parts)
    or
    exists(Raw::AdaNode last |
      last = list.getChild(max(int i | exists(list.getChild(i)) and not list.getChild(i) instanceof Raw::PragmaNode))
    |
      last instanceof Raw::ReturnStmt or
      last instanceof Raw::ExtendedReturnStmt or
      last instanceof Raw::RaiseStmt or
      last instanceof Raw::GotoStmt
    ) and
    isTarget(target, _, _) and
    parts = [false, true]
  }

  /**
   * Holds if statement `s` assigns `target` in what it always evaluates: its target,
   * its expressions, the condition of an `if` (not of an `elsif`), the selector of a
   * `case`; not its branches.
   */
  private predicate ownAssigns(Raw::AdaNode s, Raw::Name target, boolean parts) {
    s.getParent() instanceof Raw::StmtList and
    exists(Raw::Identifier n | assignedAt(n, target, parts) |
      n.getParent+() = s and
      not n.getParent+() = branch(s, _) and
      not exists(Raw::ElsifStmtPart e | n.getParent+() = e and e.getParent+() = s) and
      not exists(Raw::StmtList inner | n.getParent+() = inner and inner.getParent+() = s)
    )
  }

  /**
   * Holds if statement `s`, when it completes normally, has assigned `target`: an
   * assignment to it, a call with it as an `out` actual, or an `if` with
   * an `else` or a `case` whose every branch assigns it. With `parts`, assigning a
   * part of it counts (see `assignedAt`); AdaControl's rule is without.
   */
  predicate assigns(Raw::AdaNode s, Raw::Name target, boolean parts) {
    ownAssigns(s, target, parts)
    or
    exists(s.(Raw::IfStmt).getElsePart().getStmts()) and branchesAssign(s, 0, target, parts)
    or
    s instanceof Raw::CaseStmt and branchesAssign(s, 0, target, parts)
  }

  /**
   * Holds if `n` comes after a statement that assigns `target`: some statement around
   * `n` (or `n` itself) is preceded, in its statement list, by one that assigns it.
   */
  predicate precededByAssign(Raw::AdaNode n, Raw::Name target, boolean parts) {
    exists(Raw::AdaNode t, Raw::StmtList list, int k, int j |
      t = n.getParent*() and
      t = list.getChild(k) and
      j < k and
      assigns(list.getChild(j), target, parts)
    )
    or
    // `if F (X) then ... X ...`: the condition assigns before the branch
    exists(Raw::AdaNode s | n.getParent+() = branch(s, _) and ownAssigns(s, target, parts))
  }

  /**
   * Holds if identifier `n` reads the value of `target`: it names it, is not only
   * written, and is not the prefix of an attribute that does not read the value
   * (`'First`, `'Last`, `'Length`, `'Range`, `'Size`, `'Address`, `'Access`, ...).
   */
  predicate isRead(Raw::Identifier n, Raw::Name target) {
    n = anAccess(target) and
    not assignedAt(n, target, false) and
    not (DirectlyAccessedGlobals::written(n, false) and not DirectlyAccessedGlobals::written(n, true)) and
    not exists(Raw::AttributeRef a | a.getPrefix() = n |
      a.getAttribute().getText().toLowerCase() =
        [
          "first", "last", "length", "range", "size", "component_size", "alignment",
          "address", "access", "unchecked_access", "unrestricted_access", "constrained"
        ]
    )
  }

  /** Holds if `target` has an initial value in its declaration. */
  predicate hasInitializer(Raw::Name target) { exists(target.(Variable).getInitializer()) }

  /**
   * Holds if `target`, of body `b`, is assigned while the declarations of `b` are
   * elaborated: an `out` actual in an initial value (`R : constant T := F (Target)`).
   */
  predicate assignedInDeclarations(Raw::Name target, Raw::SubpBody b, boolean parts) {
    isTarget(target, b, _) and
    exists(Raw::Identifier n | assignedAt(n, target, parts) and n.getParent+() = b.getDecls())
  }

  /** Holds if `target`, of body `b`, is assigned in the initial sequence of `b` (`parts`: see `assigns`). */
  predicate initializedInSequence(Raw::Name target, Raw::SubpBody b, boolean parts) {
    isTarget(target, b, _) and
    (
      exists(int i | i < initialEnd(b) and assigns(bodyStmt(b, i), target, parts))
      or
      assignedInDeclarations(target, b, parts)
    )
  }

  /* --- subrules -------------------------------------------------------------- */

  /**
   * `variable`, `out_parameter`: `target` (of `kind`) of body `b` has no initial value
   * and is not assigned in the initial sequence of `b` (`parts`: see `assigns`). A variable that is never read
   * is left to `ada/unused-local`.
   */
  predicate notSafelyInitialized(Raw::Name target, Raw::SubpBody b, string kind, boolean parts) {
    isTarget(target, b, kind) and
    not hasInitializer(target) and
    parts = [false, true] and
    not initializedInSequence(target, b, parts) and
    (
      // a variable with no non-trivial statement after it is only read in the initial
      // sequence, where `readBeforeAssign` reports it
      kind = "variable" and isRead(_, target) and exists(firstNonTrivial(b))
      or
      // `out` parameters are not passed back when an exception is raised
      kind = "out_parameter" and
      (exists(firstNonTrivial(b)) or not bodyStmt(b, initialEnd(b) - 1) instanceof Raw::RaiseStmt)
    )
  }

  /**
   * `out_parameter`: `return` statement `r`, in the initial sequence of `b`, may return
   * before `out` parameter `p` is assigned.
   */
  predicate returnBeforeAssign(Raw::ReturnStmt r, Parameter p, Raw::SubpBody b, boolean parts) {
    isTarget(p, b, "out_parameter") and
    inInitialSequence(r, b) and
    parts = [false, true] and
    not precededByAssign(r, p, parts) and
    not assignedInDeclarations(p, b, parts)
  }

  /**
   * `variable`, `out_parameter`: `n`, in the initial sequence of body `b`, reads target
   * `target` before it is assigned.
   */
  predicate readBeforeAssign(Raw::Identifier n, Raw::Name target, Raw::SubpBody b, boolean parts) {
    isTarget(target, b, _) and
    not hasInitializer(target) and
    isRead(n, target) and
    inInitialSequence(n, b) and
    parts = [false, true] and
    not precededByAssign(n, target, parts) and
    not assignedInDeclarations(target, b, parts)
  }

  /**
   * `initialized_variable`: local variable `v` of body `b` has an initial value, but is
   * assigned in the initial sequence before anything reads it: the initial value is
   * never used.
   */
  predicate redundantInitializer(Variable v, Raw::SubpBody b) {
    isTarget(v, b, "variable") and
    hasInitializer(v) and
    initializedInSequence(v, b, false) and
    forall(Raw::Identifier n | isRead(n, v) | precededByAssign(n, v, false))
  }
}
