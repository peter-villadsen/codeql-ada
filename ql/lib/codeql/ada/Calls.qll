/**
 * Calls to subprograms (Phase 12, `docs/phase12-plan.md`).
 *
 * A `Call` is a call the call graph resolves (D-021): written with or without
 * parentheses, as a statement or in an expression, in prefixed-view notation
 * (`Obj.Op (X)`), to a protected operation, to a user-defined operator (`A - B`), or
 * through a renaming. Indexing, slicing and type conversions, which Ada writes like
 * calls, are not calls, and neither is a call that does not resolve. Calls through
 * access-to-subprogram values, dispatching calls (bound to their static target),
 * entry calls and calls to generic instances are the named v1 limitations of
 * `docs/dataflow-design.md`.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.dataflow.internal.SsaImpl as SsaImpl

/** A call to a subprogram that resolves. */
class Call extends Raw::Expr {
  Call() { exists(SsaImpl::getCallTarget(this)) }

  /** Gets the declaration this call names, before renamings are followed. */
  private Raw::BasicDecl getNamedDecl() { result = SsaImpl::getCallTarget(this) }

  /**
   * Gets the subprogram this call invokes. Renamings are followed to the subprogram
   * renamed, except where that subprogram cannot be identified (a renaming of an
   * attribute, an entry or a prefixed view), where the target is the renaming.
   */
  Subprogram getTarget() {
    exists(Raw::BasicDecl d |
      d = SsaImpl::resolveSubpRenaming(this.getNamedDecl())
      or
      not exists(SsaImpl::resolveSubpRenaming(this.getNamedDecl())) and d = this.getNamedDecl()
    |
      result.getADeclaration() = d
    )
  }

  /**
   * Gets the argument this call passes for its target's `i`th parameter (0-based,
   * counting each name of `A, B : T` separately), whether positional or named. In
   * prefixed-view notation (`Obj.Op (X)`), `Obj` is argument 0. A parameter left to
   * its default has no argument.
   */
  Raw::Expr getArgument(int i) { SsaImpl::callActual(this, result, i) }

  /** Gets an argument of this call. */
  Raw::Expr getAnArgument() { result = this.getArgument(_) }

  /** Gets the argument this call passes for parameter `p` of its target. */
  Raw::Expr getArgumentFor(Parameter p) {
    p = this.getTarget().getAParameter() and result = this.getArgument(p.getIndex())
  }

  /** Gets the argument this call passes for its target's parameter named `name`, ignoring case. */
  bindingset[name]
  Raw::Expr getArgumentByName(string name) {
    exists(Parameter p | p.hasName(name) and result = this.getArgumentFor(p))
  }

  /** Gets the number of arguments this call passes explicitly (not defaulted). */
  int getNumberOfArguments() { result = count(this.getAnArgument()) }

  /**
   * Gets the subprogram this call is written in: the one whose body most closely
   * encloses it. No result for a call at library level (in a package's
   * initialisation or a declaration's default).
   */
  Subprogram getCaller() {
    exists(Raw::BaseSubpBody body |
      body = this.getParent+() and
      not exists(Raw::BaseSubpBody inner | inner = this.getParent+() and inner.getParent+() = body) and
      result.getBody() = body
    )
  }

  /** Holds if this call is a procedure call statement (`P (X);`, `P;`). */
  predicate isStatement() { this = any(Raw::CallStmt s).getCall() }
}
