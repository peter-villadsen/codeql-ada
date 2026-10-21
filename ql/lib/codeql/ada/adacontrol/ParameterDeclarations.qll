/**
 * AdaControl rule `Parameter_Declarations`: the number and kinds of the parameters of
 * callable entities (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations

module ParameterDeclarations {
  /** Gets the parameter list of callable declaration `c`: a subprogram spec, a body without one, an entry. */
  private Raw::Params params(Raw::BasicDecl c) {
    result = c.(Raw::ClassicSubpDecl).getSubpSpec().getSubpParams() and
    not c instanceof Raw::FormalSubpDecl
    or
    result = c.(Raw::BaseSubpBody).getSubpSpec().getSubpParams() and
    not ada_body_part(_, c) and
    not c instanceof Raw::SubpRenamingDecl
    or
    result = c.(Raw::GenericSubpDecl).getSubpDecl().getSubpSpec().getSubpParams()
    or
    result = c.(Raw::EntryDecl).getSpec().getEntryParams()
  }

  /** Holds if `c` is a callable entity whose parameters this rule checks. */
  predicate isCallable(Raw::BasicDecl c) {
    exists(Raw::SubpSpec s |
      s = [c.(Raw::ClassicSubpDecl).getSubpSpec(), c.(Raw::BaseSubpBody).getSubpSpec()] and
      not c instanceof Raw::FormalSubpDecl and
      not ada_body_part(_, c) and
      not c instanceof Raw::SubpRenamingDecl
    )
    or
    c instanceof Raw::GenericSubpDecl
    or
    c instanceof Raw::EntryDecl
  }

  /** Gets the subprogram spec of `c`, if it is not an entry. */
  private Raw::SubpSpec spec(Raw::BasicDecl c) {
    result = c.(Raw::ClassicSubpDecl).getSubpSpec() or
    result = c.(Raw::BaseSubpBody).getSubpSpec() or
    result = c.(Raw::GenericSubpDecl).getSubpDecl().getSubpSpec()
  }

  /** Holds if `c` is declared in a protected unit. */
  private predicate inProtected(Raw::AdaNode c) {
    c.getParent+() instanceof Raw::ProtectedDef or c.getParent+() instanceof Raw::ProtectedBody
  }

  /** Holds if `c` has a parameter of a tagged type declared in the same package part: a primitive. */
  private predicate isDispatching(Raw::BasicDecl c) {
    exists(Raw::ParamSpec p, Type t |
      p = params(c).getParams().getChild(_) and
      t = namedType(p.getTypeExpr()) and
      t.isTagged() and
      t.getParent() = c.getParent()
    )
  }

  /**
   * Gets a callable kind of `c`, as AdaControl names it: `function`, `procedure`,
   * `dispatching_function`, `dispatching_procedure`, `protected_function`,
   * `protected_procedure`, `protected_entry`, `task_entry`.
   */
  string callableKind(Raw::BasicDecl c) {
    isCallable(c) and
    (
      exists(string k |
        spec(c).getSubpKind() instanceof Raw::SubpKindFunction and k = "function"
        or
        spec(c).getSubpKind() instanceof Raw::SubpKindProcedure and k = "procedure"
      |
        if inProtected(c)
        then result = "protected_" + k
        else (
          result = k
          or
          isDispatching(c) and result = "dispatching_" + k
        )
      )
      or
      c instanceof Raw::EntryDecl and
      if inProtected(c) then result = "protected_entry" else result = "task_entry"
    )
  }

  /** Gets a parameter (one defining name of a group) of `c`, with its group `p`. */
  private Raw::DefiningName parameter(Raw::BasicDecl c, Raw::ParamSpec p) {
    p = params(c).getParams().getChild(_) and result = p.getIds().getChild(_)
  }

  /** Holds if parameter group `p` matches the subrule `subrule` (`all_parameters`, `in_parameters`, ...). */
  private predicate matches(Raw::ParamSpec p, string subrule) {
    subrule = "all_parameters"
    or
    subrule = "in_parameters" and (p.getMode() instanceof Raw::ModeIn or p.getMode() instanceof Raw::ModeDefault)
    or
    subrule = "out_parameters" and p.getMode() instanceof Raw::ModeOut
    or
    subrule = "in_out_parameters" and p.getMode() instanceof Raw::ModeInOut
    or
    subrule = "defaulted_parameters" and exists(p.getDefaultExpr())
    or
    subrule = "access_parameters" and
    p.getTypeExpr().(Raw::AnonymousType).getTypeDecl().getTypeDef() instanceof Raw::AccessDef
    or
    subrule = "tagged_parameters" and namedType(p.getTypeExpr()).isTagged()
    or
    subrule = "class_wide_parameters" and
    p.getTypeExpr().(Raw::SubtypeIndication).getName().(Raw::AttributeRef).getAttribute().getValue().toLowerCase() =
      "class"
  }

  /** Gets the number of parameters of `c` that count for `subrule`. */
  int parameterCount(Raw::BasicDecl c, string subrule) {
    isCallable(c) and
    subrule =
      [
        "all_parameters", "in_parameters", "out_parameters", "in_out_parameters",
        "defaulted_parameters", "access_parameters", "tagged_parameters", "class_wide_parameters"
      ] and
    result = strictcount(Raw::DefiningName dn | exists(Raw::ParamSpec p | dn = parameter(c, p) and matches(p, subrule)))
    or
    isCallable(c) and
    subrule =
      [
        "all_parameters", "in_parameters", "out_parameters", "in_out_parameters",
        "defaulted_parameters", "access_parameters", "tagged_parameters", "class_wide_parameters"
      ] and
    not exists(Raw::ParamSpec p | exists(parameter(c, p)) and matches(p, subrule)) and
    result = 0
  }

  /**
   * `single_out_parameter`: `c` has exactly one `out` parameter; with `noInout`, not when
   * it also has an `in out` one.
   */
  predicate singleOutParameter(Raw::BasicDecl c, boolean noInout) {
    parameterCount(c, "out_parameters") = 1 and
    (
      noInout = false
      or
      noInout = true and parameterCount(c, "in_out_parameters") = 0
    )
  }
}
