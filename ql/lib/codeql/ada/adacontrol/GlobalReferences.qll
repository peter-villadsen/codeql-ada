/**
 * AdaControl rule `Global_References`: the global variables that given *roots* --
 * subprograms, tasks, protected objects -- read or write, directly or through the
 * subprograms and protected operations they call (`docs/adacontrol.md`).
 *
 * An access is attributed to the innermost subprogram body, entry body or task body
 * around it (`bodyOf`); a task's `accept` statements are part of its body. A body
 * *calls* the bodies of the subprograms it calls (`Call.getTarget()`) and of the
 * protected entries it calls (`calls`). A variable is global to a body when it is not
 * declared inside that body. As in AdaControl, calls through access-to-subprogram
 * values and dispatching calls are not followed, nor calls of subprograms whose body
 * is not in the database (the Ada library).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.DirectlyAccessedGlobals
private import codeql.ada.adacontrol.ObjectDeclarations
private import codeql.ada.adacontrol.TypeCategories

module GlobalReferences {
  /** Holds if `n` is a body accesses are attributed to. */
  private predicate isBody(Raw::AdaNode n) {
    n instanceof Raw::BaseSubpBody and not n instanceof Raw::SubpRenamingDecl
    or
    n instanceof Raw::EntryBody
    or
    n instanceof Raw::TaskBody
  }

  /**
   * Gets the body `n` is in: the innermost subprogram body, entry body or task body
   * around it. No result in a package's own statements or declarations.
   */
  Raw::AdaNode bodyOf(Raw::AdaNode n) {
    result = n.getParent+() and
    isBody(result) and
    not exists(Raw::AdaNode inner | inner = n.getParent+() and isBody(inner) and inner.getParent+() = result)
  }

  /** Holds if the declaration of `v` is inside `n`. */
  private predicate declaredIn(Variable v, Raw::AdaNode n) { v.getDeclaration().getParent+() = n }

  /**
   * Holds if `v` is a variable the rule checks: not a constant, a renaming (whose
   * accesses are not followed to the object renamed), a loop variable, a component of
   * a protected object (always accessed under its lock) or an object of a task or
   * protected type (whose operations synchronize themselves).
   */
  predicate isVariable(Variable v) {
    not v.isConstant() and
    not v.isRenaming() and
    not v.isLoopVariable() and
    not v.getDeclaration().getParent+() instanceof Raw::ProtectedDef and
    not TypeCategories::category(v.getType(), true) = ["task", "protected"]
  }

  /** Holds if `v` is `Atomic` or `Atomic_Components`, by aspect or pragma. */
  predicate isAtomic(Variable v) {
    ObjectDeclarations::hasAspectOrPragma(v.getDeclaration(), ["atomic", "atomic_components"])
  }

  /** Gets the body of protected entry `e`. */
  private Raw::EntryBody entryBody(Raw::EntryDecl e) {
    e.getParent+() instanceof Raw::ProtectedDef and ada_body_part(e, result)
  }

  /**
   * Holds if body `caller` calls body `callee`: a call of a subprogram whose body is
   * `callee`, or of a protected entry whose body is `callee`.
   */
  predicate calls(Raw::AdaNode caller, Raw::AdaNode callee) {
    exists(Call c | caller = bodyOf(c) and callee = c.getTarget().getBody())
    or
    exists(Raw::Name n |
      caller = bodyOf(n) and
      callee = entryBody(n.getReferencedDecl()) and
      not n.getParent() instanceof Raw::AttributeRef
    )
  }

  /**
   * Holds if identifier `n`, in body `b`, reads (`mode` = `read`) or writes (`write`)
   * `v`, declared outside `b`; an `in out` actual does both. The prefix of `'Access` or
   * `'Address` is not an access: aliases are not followed.
   */
  predicate directAccess(Raw::AdaNode b, Variable v, Raw::Identifier n, string mode) {
    isVariable(v) and
    n = v.getAnAccess() and
    b = bodyOf(n) and
    not declaredIn(v, b) and
    not DirectlyAccessedGlobals::isAliased(n) and
    not exists(Raw::DottedName d | n = d.getSuffix() and DirectlyAccessedGlobals::isAliased(d)) and
    (
      DirectlyAccessedGlobals::written(n, _) and mode = "write"
      or
      (DirectlyAccessedGlobals::written(n, true) or not DirectlyAccessedGlobals::written(n, _)) and
      mode = "read"
    )
  }

  /**
   * Holds if body `b`, or a body it calls, directly or not, reads or writes (`mode`)
   * `v`, declared outside `b` and the bodies in between.
   */
  predicate accesses(Raw::AdaNode b, Variable v, string mode) {
    directAccess(b, v, _, mode)
    or
    exists(Raw::AdaNode callee | calls(b, callee) and accesses(callee, v, mode) and not declaredIn(v, b))
  }

  /* --- roots ----------------------------------------------------------------- */

  /**
   * Gets the kind of root `r`, AdaControl's keyword for it: `function` or
   * `procedure` for a subprogram of the source with a body, `task` for a task body,
   * `protected` for a protected body.
   */
  string rootKind(Raw::AdaNode r) {
    exists(Subprogram s | s = r and s.fromSource() and exists(s.getBody()) |
      s.isFunction() and result = "function"
      or
      s.isProcedure() and result = "procedure"
    )
    or
    r instanceof Raw::TaskBody and result = "task"
    or
    r instanceof Raw::ProtectedBody and result = "protected"
  }

  /**
   * Holds if root `r` is the body of a task or protected type, not of a single
   * object: several objects of the type may access a global at once.
   */
  predicate isTypeRoot(Raw::AdaNode r) {
    exists(rootKind(r)) and DirectlyAccessedGlobals::isTypeBody(r)
  }

  /** Gets the name of root `r`. */
  string rootName(Raw::AdaNode r) {
    result = r.(Subprogram).getName()
    or
    result = r.(Raw::TaskBody).getName().getName().getText()
    or
    result = r.(Raw::ProtectedBody).getName().getName().getText()
  }

  /**
   * Gets a body root `r` starts in: a subprogram's body, the task body, or the body of
   * an operation or entry of the protected body.
   */
  Raw::AdaNode rootBody(Raw::AdaNode r) {
    exists(rootKind(r)) and
    (
      result = r.(Subprogram).getBody()
      or
      result = r.(Raw::TaskBody)
      or
      exists(Raw::ProtectedBody p | p = r |
        result = p.getDecls().getDecls().getChild(_) and isBody(result)
      )
    )
  }

  /** `read`, `written`: root `r` reads (`mode` = `read`) or writes (`write`) global `v`. */
  predicate reference(Raw::AdaNode r, Variable v, string mode) { accesses(rootBody(r), v, mode) }

  /** Holds if root `r` reaches body `b`: one of its bodies, or a body they call, directly or not. */
  predicate reaches(Raw::AdaNode r, Raw::AdaNode b) {
    b = rootBody(r)
    or
    exists(Raw::AdaNode mid | reaches(r, mid) and calls(mid, b))
  }

  /**
   * `all`: identifier `n` is a read or write (`mode`) of `v`, global to root `r`, in a
   * body `r` reaches.
   */
  predicate referenceSite(Raw::AdaNode r, Variable v, Raw::Identifier n, string mode) {
    reference(r, v, mode) and
    exists(Raw::AdaNode b | reaches(r, b) and directAccess(b, v, n, mode))
  }
}

/** A choice of roots for the `multiple` subrules: AdaControl's list of roots. */
signature predicate rootSig(Raw::AdaNode r);

/** The subrules `multiple` and `multiple_non_atomic`, for the roots `isRoot` holds for. */
module GlobalReferencesMultiple<rootSig/1 isRoot> {
  /** Gets a root of `isRoot` that reads or writes (`mode`) `v`. */
  Raw::AdaNode accessor(Variable v, string mode) { isRoot(result) and GlobalReferences::reference(result, v, mode) }

  /**
   * `multiple`: `v` is accessed by more than one root, or by the body of a task or
   * protected type, of which there may be several objects.
   */
  predicate multiple(Variable v) {
    strictcount(accessor(v, _)) > 1
    or
    GlobalReferences::isTypeRoot(accessor(v, _))
  }

  /**
   * `multiple_non_atomic`: `multiple`, except for an atomic variable written by one
   * root at most (and not by a task or protected type).
   */
  predicate multipleNonAtomic(Variable v) {
    multiple(v) and
    not (
      GlobalReferences::isAtomic(v) and
      count(accessor(v, "write")) <= 1 and
      not GlobalReferences::isTypeRoot(accessor(v, "write"))
    )
  }
}
