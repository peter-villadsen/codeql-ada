/**
 * AdaControl rule `Directly_Accessed_Globals`: variables declared directly in package
 * bodies must be accessed only through dedicated callable entities, one that reads
 * them and one that writes them (`docs/adacontrol.md`).
 *
 * An access is attributed to the innermost subprogram body, entry body or `accept`
 * statement around it, its *callable*. A callable is *dedicated* to a variable when it
 * is declared at the same level, not nested and not generic: a subprogram of the
 * package body (kind `plain`), an operation of a single protected object of the
 * package body (`protected`), or an `accept` statement of a single task of the package
 * body (`accept`). The operations of one protected object, and the `accept` statements
 * of one task, are one *accessor*, since they exclude one another; a plain subprogram
 * is an accessor of its own. Each variable may be read by one accessor and written by
 * one accessor; an accessor that both reads and writes it must be the only one.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.Places
private import codeql.ada.adacontrol.TypeCategories

module DirectlyAccessedGlobals {
  /**
   * Holds if `v` is a global of a package body: a variable declared directly in the
   * declarations of a package body (generic or not). Constants, renamings and objects
   * of task or protected types, whose operations synchronize themselves, are not.
   */
  predicate isGlobal(Variable v) {
    exists(Raw::ObjectDecl d | d = v.getDeclaration() |
      Places::declarativePart(d).getParent() instanceof Raw::PackageBody
    ) and
    not v.isConstant() and
    not v.isRenaming() and
    not TypeCategories::category(v.getType(), true) = ["task", "protected"]
  }

  /** Holds if `n` is a construct an access can be attributed to. */
  private predicate isCallable(Raw::AdaNode n) {
    n instanceof Raw::BaseSubpBody and not n instanceof Raw::SubpRenamingDecl
    or
    n instanceof Raw::EntryBody
    or
    n instanceof Raw::AcceptStmt
    or
    n instanceof Raw::TaskBody
  }

  /**
   * Gets the callable `n` is in: the innermost subprogram body, entry body, `accept`
   * statement or task body around it. No result in a package's own statements or
   * declarations.
   */
  Raw::AdaNode callable(Raw::AdaNode n) {
    result = n.getParent+() and
    isCallable(result) and
    not exists(Raw::AdaNode inner | inner = n.getParent+() and isCallable(inner) and inner.getParent+() = result)
  }

  /** Gets the protected body whose declarations hold `c`, if `c` is a protected operation. */
  private Raw::ProtectedBody protectedBodyOf(Raw::AdaNode c) {
    Places::declarativePart(c) = result.getDecls()
  }

  /** Gets the task body an `accept` statement `c` belongs to. */
  private Raw::TaskBody taskBodyOf(Raw::AcceptStmt c) {
    result = c.getParent+() and
    not exists(Raw::AdaNode inner |
      inner = c.getParent+() and
      inner.getParent+() = result and
      (isCallable(inner) and not inner instanceof Raw::AcceptStmt)
    )
  }

  /**
   * Gets the kind of callable `c`, AdaControl's `<kind>`: `plain` for a subprogram that
   * is not protected, `protected` for an operation (or entry) of a protected body,
   * `accept` for an `accept` statement. A task body has none.
   */
  string kind(Raw::AdaNode c) {
    isCallable(c) and
    (
      c instanceof Raw::AcceptStmt and result = "accept"
      or
      (c instanceof Raw::BaseSubpBody or c instanceof Raw::EntryBody) and
      if exists(protectedBodyOf(c)) then result = "protected" else result = "plain"
    )
  }

  /**
   * Gets the accessor callable `c` belongs to: the protected body of a protected
   * operation, the task body of an `accept` statement, else `c` itself.
   */
  Raw::AdaNode accessor(Raw::AdaNode c) {
    kind(c) = "protected" and result = protectedBodyOf(c)
    or
    kind(c) = "accept" and result = taskBodyOf(c)
    or
    kind(c) = "plain" and result = c
  }

  /** Gets the name of accessor `a`: the subprogram's, the protected object's or the task's. */
  string accessorName(Raw::AdaNode a) {
    result = a.(Raw::BaseSubpBody).getSubpSpec().getSubpName().getName().getText()
    or
    result = a.(Raw::ProtectedBody).getName().getName().getText()
    or
    result = a.(Raw::TaskBody).getName().getName().getText()
  }

  /** Holds if body `b` is declared at the same level as `v`: directly, or as the subunit of a stub there. */
  private predicate sameLevel(Raw::AdaNode b, Variable v) {
    exists(Raw::DeclarativePart part | part = Places::declarativePart(v.getDeclaration()) |
      Places::declarativePart(b) = part
      or
      exists(Raw::BodyStub stub | Places::declarativePart(stub) = part and ada_body_part(stub, b))
    )
  }

  /** Holds if body `b` is the body of a generic subprogram. */
  private predicate isGenericBody(Raw::AdaNode b) {
    exists(Raw::GenericSubpDecl g | ada_body_part(g, b) or ada_body_part(g.getSubpDecl(), b))
  }

  /**
   * Holds if protected or task body `b` is the body of a protected or task type, not of
   * a single object. The extractor does not pair these bodies with their declarations;
   * a type and its body have the same qualified name.
   */
  predicate isTypeBody(Raw::AdaNode b) {
    (b instanceof Raw::ProtectedBody or b instanceof Raw::TaskBody) and
    exists(Raw::BasicDecl d |
      ada_body_part(d, b) or d.getQualifiedName() = b.(Raw::BasicDecl).getQualifiedName()
    |
      d instanceof Raw::ProtectedTypeDecl or
      d instanceof Raw::TaskTypeDecl and not d instanceof Raw::SingleTaskTypeDecl
    )
  }

  /**
   * Holds if callable `c` is dedicated to `v`, and, when it is not, `reason` says why:
   * `nested`, `generic` or `type` (an operation of a protected or task type). A task
   * body itself, outside its `accept` statements, is never dedicated (`task body`).
   */
  predicate notDedicated(Raw::AdaNode c, Variable v, string reason) {
    isGlobal(v) and
    isCallable(c) and
    (
      c instanceof Raw::TaskBody and reason = "task body"
      or
      exists(Raw::AdaNode a | a = accessor(c) |
        not sameLevel(a, v) and reason = "nested"
        or
        sameLevel(a, v) and kind(c) = "plain" and isGenericBody(a) and reason = "generic"
        or
        sameLevel(a, v) and kind(c) != "plain" and isTypeBody(a) and reason = "type"
      )
    )
  }

  /** Holds if callable `c` is dedicated to global `v`. */
  predicate isDedicated(Raw::AdaNode c, Variable v) {
    isGlobal(v) and exists(kind(c)) and not notDedicated(c, v, _)
  }

  /** Holds if `n` is the target of an `'Access`-like or `'Address` attribute: an alias the rule cannot follow. */
  predicate isAliased(Raw::Name n) {
    exists(Raw::AttributeRef a | a.getPrefix() = n |
      a.getAttribute().getValue().toLowerCase() =
        ["access", "unchecked_access", "unrestricted_access", "address"]
    )
  }

  /** Holds if `n` names an object of an access type, so that a part of it is a dereference. */
  private predicate isAccessValue(Raw::Name n) {
    TypeCategories::category(n.getType(), true) = "access"
  }

  /**
   * Holds if name `n` is written: the target of an assignment, an actual for an `out`
   * or `in out` parameter (`inOut` true for `in out`), or the prefix of a component or
   * element that is written. Not through a dereference.
   */
  predicate written(Raw::Name n, boolean inOut) {
    n = any(Raw::AssignStmt s).getDest() and inOut = false
    or
    exists(Call c, Parameter p | n = c.getArgumentFor(p) |
      p.getMode() = "out" and inOut = false
      or
      p.getMode() = "in out" and inOut = true
    )
    or
    exists(Raw::DottedName d | n = d.getPrefix() |
      d.getReferencedDecl() instanceof Raw::ComponentDecl and
      not isAccessValue(n) and
      written(d, inOut)
    )
    or
    exists(Raw::CallExpr e | n = e.getName() |
      TypeCategories::category(n.getType(), true) = "array" and
      written(e, inOut)
    )
    or
    // `Pkg.V`, written
    exists(Raw::DottedName d | n = d.getSuffix() | written(d, inOut))
  }

  /**
   * Holds if identifier `n` reads (`mode` = `read`) or writes (`write`) global `v`;
   * an `in out` actual does both. The prefix of `'Access` or `'Address` is not counted.
   */
  predicate access(Variable v, Raw::Identifier n, string mode) {
    isGlobal(v) and
    n = v.getAnAccess() and
    not n.getParent+() = v.getDeclaration() and
    not isAliased(n) and
    not exists(Raw::DottedName d | n = d.getSuffix() and isAliased(d)) and
    (
      written(n, _) and mode = "write"
      or
      (written(n, true) or not written(n, _)) and mode = "read"
    )
  }

  /**
   * Holds if `n` accesses global `v` outside a callable dedicated to it: in the
   * package's own statements or declarations (`reason` = `outside`), or in a callable
   * that is not dedicated (`nested`, `generic`, `type`, `task body`).
   */
  predicate undedicatedAccess(Variable v, Raw::Identifier n, string reason) {
    access(v, n, _) and
    (
      not exists(callable(n)) and reason = "outside"
      or
      notDedicated(callable(n), v, reason)
    )
  }

  /** Holds if accessor `a`, through a dedicated callable, reads (`mode` = `read`) or writes `v`. */
  predicate accessedBy(Variable v, Raw::AdaNode a, string mode) {
    exists(Raw::Identifier n, Raw::AdaNode c |
      access(v, n, mode) and c = callable(n) and isDedicated(c, v) and a = accessor(c)
    )
  }

  /**
   * Holds if global `v` is accessed by too many dedicated accessors: read by more than
   * one, written by more than one, or read and written by one and accessed by another.
   */
  predicate tooManyAccessors(Variable v) {
    strictcount(Raw::AdaNode a | accessedBy(v, a, "read")) > 1
    or
    strictcount(Raw::AdaNode a | accessedBy(v, a, "write")) > 1
    or
    exists(Raw::AdaNode a | accessedBy(v, a, "read") and accessedBy(v, a, "write")) and
    strictcount(Raw::AdaNode a | accessedBy(v, a, _)) > 1
  }
}
