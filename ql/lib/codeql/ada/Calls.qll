/**
 * Calls to subprograms (Phase 12, `docs/phase12-plan.md`).
 *
 * A `Call` is a call that resolves (D-021, `codeql.ada.internal.CallResolution`):
 * written with or without parentheses, as a statement or in an expression, in
 * prefixed-view notation (`Obj.Op (X)`), to a protected operation, to a user-defined
 * operator (`A - B`), or through a renaming. Indexing, slicing and type conversions, which Ada writes like
 * calls, are not calls, and neither is a call that does not resolve. A call inside a
 * generic subprogram to the generic itself is a call. Calls through
 * access-to-subprogram values, dispatching calls (bound to their static target),
 * entry calls and calls to generic instances are the named v1 limitations of
 * `docs/dataflow-design.md`.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.internal.CallResolution as CallResolution
private import codeql.ada.internal.Formals as Formals

/** Gets the name of the pragma or aspect `n` is an argument of, lower-cased. */
private string pragmaOrAspectName(Raw::AdaNode n) {
  exists(Raw::PragmaNode p | n.getParent+() = p | result = p.getId().getValue().toLowerCase())
  or
  exists(Raw::AspectAssoc a | n.getParent+() = a.getExpr() or n = a.getExpr() |
    result = a.getId().(Raw::Name).getText().toLowerCase()
  )
}

/**
 * Holds if `n` is evaluated where it stands, judged from the syntax alone: this is
 * what makes a name that resolves to a subprogram a call. Not evaluated: an `end`
 * name, a name in a `with` or `use` clause, the name a renaming renames, a subprogram passed as a generic actual or
 * given as a formal subprogram's default, and the arguments of pragmas and aspects
 * that name an entity rather than state a condition (`pragma Inline (Foo)`,
 * `Constant_Indexing => Element`). Unlike data flow, which counts a call only where
 * the CFG has a node for it, this includes calls evaluated during elaboration, such
 * as one in a range constraint (`range 1 .. F (X)`).
 */
private predicate isEvaluatedSyntactically(Raw::AdaNode n) {
  not n.getParent*() instanceof Raw::EndName and
  // the operator of `A - B` resolves to `"-"`, but the call is the whole `BinOp`
  not n instanceof Raw::Op and
  // `with Ada.Strings.Unbounded.Hash;` names a library-level function
  not n.getParent+() instanceof Raw::WithClause and
  not n.getParent+() instanceof Raw::UseClause and
  not n = any(Raw::RenamingClause r).getRenamedObject() and
  not n = any(Raw::FormalSubpDecl f).getDefaultExpr() and
  not (
    not n instanceof Raw::CallExpr and
    n = any(Raw::GenericInstantiation g).getChild(_).(Raw::AssocList).getChild(_).(Raw::ParamAssoc).getRExpr()
  ) and
  not exists(string name | name = pragmaOrAspectName(n) |
    not name =
      [
        "assert", "assume", "check", "debug", "loop_invariant", "loop_variant", "assert_and_cut",
        "precondition", "postcondition", "pre", "post", "pre'class", "post'class",
        "predicate", "static_predicate", "dynamic_predicate", "type_invariant",
        "type_invariant'class", "invariant", "contract_cases", "default_initial_condition",
        "initial_condition", "address", "size", "alignment", "storage_size", "priority",
        "interrupt_priority", "cpu", "default_value", "default_component_value"
      ]
  )
}

private module Resolution = CallResolution::Make<isEvaluatedSyntactically/1, Formals::callableSpecOf/1>;

/** A call to a subprogram that resolves. */
class Call extends Raw::Expr {
  Call() { exists(Resolution::getCallTarget(this)) }

  /** Gets the declaration this call names, before renamings are followed. */
  private Raw::BasicDecl getNamedDecl() { result = Resolution::getCallTarget(this) }

  /**
   * Gets the subprogram this call invokes. Renamings are followed to the subprogram
   * renamed, except where that subprogram cannot be identified (a renaming of an
   * attribute, an entry or a prefixed view), where the target is the renaming.
   */
  Subprogram getTarget() {
    exists(Raw::BasicDecl d |
      d = CallResolution::resolveSubpRenaming(this.getNamedDecl())
      or
      not exists(CallResolution::resolveSubpRenaming(this.getNamedDecl())) and d = this.getNamedDecl()
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
  Raw::Expr getArgument(int i) { Resolution::callActual(this, result, i) }

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
