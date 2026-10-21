/**
 * AdaControl rule `Naming_Convention`: the form of identifiers, by kind of entity
 * (`docs/adacontrol.md`).
 *
 * `kind(dn, k)` gives the most specific of AdaControl's filter kinds for the defining name
 * `dn`; `parentKind` is the hierarchy, and `appliesTo(dn, k)` holds for `kind(dn, _)`
 * and every kind above it, up to `all`. `Convention<rule>` checks names against
 * positive and negative patterns per kind.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations as D
private import codeql.ada.adacontrol.TypeCategories

module NamingConvention {
  /** Holds if `k` is a filter kind whose parent in AdaControl's hierarchy is `parent`. */
  predicate parentKind(string k, string parent) {
    parent = "all" and
    k =
      [
        "type", "variable", "constant", "label", "stmt_name", "subprogram", "package", "task",
        "protected", "exception", "generic", "renaming"
      ]
    or
    parent = "type" and
    k =
      [
        "discrete_type", "array_type", "record_type", "access_type", "private_type",
        "generic_formal_type"
      ]
    or
    parent = "discrete_type" and
    k = ["enumeration_type", "integer_type", "floating_point_type", "fixed_point_type"]
    or
    parent = "integer_type" and k = ["signed_integer_type", "modular_integer_type"]
    or
    parent = "fixed_point_type" and k = ["binary_fixed_point_type", "decimal_fixed_point_type"]
    or
    parent = "record_type" and
    k = ["regular_record_type", "tagged_type", "interface_type", "class_type"]
    or
    parent = "access_type" and
    k =
      [
        "access_to_regular_type", "access_to_tagged_type", "access_to_class_type",
        "access_to_sp_type", "access_to_task_type", "access_to_protected_type"
      ]
    or
    parent = "private_type" and k = "private_extension"
    or
    parent = "variable" and
    k =
      [
        "regular_variable", "field", "procedure_formal_out", "procedure_formal_in_out",
        "generic_formal_in_out"
      ]
    or
    parent = "field" and k = ["discriminant", "record_field", "protected_field"]
    or
    parent = "constant" and
    k =
      [
        "regular_constant", "named_number", "enumeration", "sp_formal_in", "generic_formal_in",
        "loop_control", "occurrence_name", "entry_index"
      ]
    or
    parent = "named_number" and k = ["integer_number", "real_number"]
    or
    parent = "stmt_name" and k = ["loop_name", "block_name"]
    or
    parent = "subprogram" and k = ["procedure", "function", "entry"]
    or
    parent = "procedure" and
    k = ["regular_procedure", "protected_procedure", "generic_formal_procedure"]
    or
    parent = "function" and
    k = ["regular_function", "protected_function", "generic_formal_function"]
    or
    parent = "entry" and k = ["task_entry", "protected_entry"]
    or
    parent = "package" and k = ["regular_package", "generic_formal_package"]
    or
    parent = "task" and k = ["task_type", "task_object"]
    or
    parent = "protected" and k = ["protected_type", "protected_object"]
    or
    parent = "generic" and k = ["generic_package", "generic_sp"]
    or
    parent = "generic_sp" and k = ["generic_procedure", "generic_function"]
    or
    parent = "renaming" and
    k =
      [
        "object_renaming", "exception_renaming", "package_renaming", "subprogram_renaming",
        "generic_renaming"
      ]
    or
    parent = "subprogram_renaming" and k = ["procedure_renaming", "function_renaming"]
    or
    parent = "generic_renaming" and k = ["generic_package_renaming", "generic_sp_renaming"]
    or
    parent = "generic_sp_renaming" and
    k = ["generic_procedure_renaming", "generic_function_renaming"]
  }

  /** Gets the kind of a type, by the definition of the type it ultimately is. */
  private string typeKind(D::Type t) {
    t.isPrivate() and
    if t.getDefinition().(Raw::DerivedTypeDef).getHasWithPrivate() instanceof Raw::WithPrivatePresent
    then result = "private_extension"
    else result = "private_type"
    or
    t.getDefinition().(Raw::DerivedTypeDef).getHasWithPrivate() instanceof Raw::WithPrivatePresent and
    result = "private_extension"
    or
    not t.isPrivate() and
    not t.getDefinition().(Raw::DerivedTypeDef).getHasWithPrivate() instanceof Raw::WithPrivatePresent and
    exists(D::Type u, Raw::TypeDef d | u = ultimate(t) and d = u.getDefinition() |
      d instanceof Raw::EnumTypeDef and result = "enumeration_type"
      or
      d instanceof Raw::SignedIntTypeDef and result = "signed_integer_type"
      or
      d instanceof Raw::ModIntTypeDef and result = "modular_integer_type"
      or
      d instanceof Raw::FloatingPointDef and result = "floating_point_type"
      or
      d instanceof Raw::OrdinaryFixedPointDef and result = "binary_fixed_point_type"
      or
      d instanceof Raw::DecimalFixedPointDef and result = "decimal_fixed_point_type"
      or
      d instanceof Raw::ArrayTypeDef and result = "array_type"
      or
      d instanceof Raw::InterfaceTypeDef and result = "interface_type"
      or
      (d instanceof Raw::RecordTypeDef or d instanceof Raw::DerivedTypeDef) and
      if u.isTagged() or t.isTagged()
      then result = "tagged_type"
      else (d instanceof Raw::RecordTypeDef and result = "regular_record_type")
      or
      d instanceof Raw::AccessToSubpDef and result = "access_to_sp_type"
      or
      exists(Raw::SubtypeIndication des | des = d.(Raw::TypeAccessDef).getSubtypeIndication() |
        des.getName() instanceof Raw::AttributeRef and result = "access_to_class_type"
        or
        not des.getName() instanceof Raw::AttributeRef and
        exists(D::Type dt | dt = TypeCategories::ultimateType(D::namedType(des)) |
          dt instanceof Raw::TaskTypeDecl and result = "access_to_task_type"
          or
          dt instanceof Raw::ProtectedTypeDecl and result = "access_to_protected_type"
          or
          dt.isTagged() and result = "access_to_tagged_type"
          or
          not dt instanceof Raw::TaskTypeDecl and
          not dt instanceof Raw::ProtectedTypeDecl and
          not dt.isTagged() and
          result = "access_to_regular_type"
        )
      )
    )
  }

  /** Gets the type `t` is, through subtypes and derivations (not private views). */
  private D::Type ultimate(D::Type t) {
    if exists(t.getParentType()) then result = ultimate(t.getParentType()) else result = t
  }

  /** Holds if `d` is declared in a generic formal part. */
  private predicate isFormal(Raw::AdaNode d) { d.getParent() instanceof Raw::GenericFormal }

  /** Holds if `d` is declared in a protected definition or body. */
  private predicate inProtected(Raw::AdaNode d) {
    d.getParent+() instanceof Raw::ProtectedDef or d.getParent+() instanceof Raw::ProtectedBody
  }

  /** Holds if `d` is a subprogram body (or stub) completing a separate declaration: not checked. */
  private predicate isCompletion(Raw::BasicDecl d) { ada_body_part(_, d) }

  /** Gets the subprogram kind of spec `s`: `procedure` or `function`. */
  private string subpKind(Raw::SubpSpec s) {
    s.getSubpKind() instanceof Raw::SubpKindProcedure and result = "procedure"
    or
    s.getSubpKind() instanceof Raw::SubpKindFunction and result = "function"
  }

  /** Gets the most specific kind of declaration `d`, for its defining names. */
  private string declKind(Raw::BasicDecl d) {
    // types
    result = typeKind(d) and
    not d instanceof Raw::IncompleteTypeDecl and
    not isFormal(d) and
    not d instanceof Raw::AnonymousTypeDecl and
    not d instanceof Raw::TaskTypeDecl and
    not d instanceof Raw::ProtectedTypeDecl
    or
    d instanceof Raw::FormalTypeDecl and result = "generic_formal_type"
    or
    // objects
    exists(Raw::ObjectDecl o | o = d and not exists(o.getRenamingClause()) |
      isFormal(o) and
      (
        o.getMode() instanceof Raw::ModeInOut and result = "generic_formal_in_out"
        or
        not o.getMode() instanceof Raw::ModeInOut and result = "generic_formal_in"
      )
      or
      not isFormal(o) and
      not o instanceof Raw::ExtendedReturnStmtObjectDecl and
      (
        if o.getHasConstant() instanceof Raw::ConstantPresent
        then result = "regular_constant"
        else
          if inProtected(o)
          then result = "protected_field"
          else result = "regular_variable"
      )
    )
    or
    d instanceof Raw::SingleTaskDecl and result = "task_object"
    or
    d instanceof Raw::SingleProtectedDecl and result = "protected_object"
    or
    d instanceof Raw::TaskTypeDecl and
    not d instanceof Raw::SingleTaskTypeDecl and
    result = "task_type"
    or
    d instanceof Raw::ProtectedTypeDecl and result = "protected_type"
    or
    d instanceof Raw::ComponentDecl and
    if inProtected(d) then result = "protected_field" else result = "record_field"
    or
    d instanceof Raw::DiscriminantSpec and result = "discriminant"
    or
    exists(Raw::ParamSpec p, Raw::BasicDecl subp | p = d and p.getParent+() = subp |
      (
        subp instanceof Raw::ClassicSubpDecl or
        subp instanceof Raw::BaseSubpBody or
        subp instanceof Raw::EntryDecl
      ) and
      not isCompletion(subp) and
      (
        p.getMode() instanceof Raw::ModeOut and result = "procedure_formal_out"
        or
        p.getMode() instanceof Raw::ModeInOut and result = "procedure_formal_in_out"
        or
        (p.getMode() instanceof Raw::ModeIn or p.getMode() instanceof Raw::ModeDefault) and
        result = "sp_formal_in"
      )
    )
    or
    exists(Raw::NumberDecl n | n = d |
      if exists(Raw::RealLiteral r | r.getParent*() = n.getExpr())
      then result = "real_number"
      else result = "integer_number"
    )
    or
    d instanceof Raw::EnumLiteralDecl and result = "enumeration"
    or
    d instanceof Raw::ForLoopVarDecl and result = "loop_control"
    or
    d instanceof Raw::ExceptionHandler and result = "occurrence_name"
    or
    d instanceof Raw::EntryIndexSpec and result = "entry_index"
    or
    d instanceof Raw::LabelDecl and result = "label"
    or
    exists(Raw::NamedStmtDecl n | n = d |
      if n.getParent().(Raw::NamedStmt).getStmt() instanceof Raw::BaseLoopStmt
      then result = "loop_name"
      else result = "block_name"
    )
    or
    // subprograms
    exists(Raw::SubpSpec s |
      s = [d.(Raw::ClassicSubpDecl).getSubpSpec(), d.(Raw::BaseSubpBody).getSubpSpec()] and
      not d instanceof Raw::SubpRenamingDecl and
      not isCompletion(d) and
      not s.getSubpName().getName() instanceof Raw::StringLiteral
    |
      d instanceof Raw::FormalSubpDecl and result = "generic_formal_" + subpKind(s)
      or
      not d instanceof Raw::FormalSubpDecl and
      not d.getParent() instanceof Raw::GenericSubpDecl and
      if inProtected(d) then result = "protected_" + subpKind(s) else result = "regular_" + subpKind(s)
    )
    or
    d instanceof Raw::EntryDecl and
    if inProtected(d) then result = "protected_entry" else result = "task_entry"
    or
    // packages, exceptions, generics
    d instanceof Raw::PackageDecl and not isFormal(d) and result = "regular_package"
    or
    d instanceof Raw::GenericPackageInstantiation and
    if isFormal(d) then result = "generic_formal_package" else result = "regular_package"
    or
    d.(Raw::GenericSubpInstantiation).getKind() instanceof Raw::SubpKindProcedure and
    result = "regular_procedure"
    or
    d.(Raw::GenericSubpInstantiation).getKind() instanceof Raw::SubpKindFunction and
    result = "regular_function"
    or
    d instanceof Raw::ExceptionDecl and not exists(d.(Raw::ExceptionDecl).getRenames()) and
    result = "exception"
    or
    d instanceof Raw::GenericPackageDecl and result = "generic_package"
    or
    exists(Raw::GenericSubpDecl g | g = d | result = "generic_" + subpKind(g.getSubpDecl().getSubpSpec()))
    or
    // renamings
    exists(d.(Raw::ObjectDecl).getRenamingClause()) and result = "object_renaming"
    or
    exists(d.(Raw::ExceptionDecl).getRenames()) and result = "exception_renaming"
    or
    d instanceof Raw::PackageRenamingDecl and result = "package_renaming"
    or
    result = subpKind(d.(Raw::SubpRenamingDecl).getSubpSpec()) + "_renaming"
    or
    d instanceof Raw::GenericPackageRenamingDecl and result = "generic_package_renaming"
    or
    exists(Raw::GenericSubpRenamingDecl r | r = d |
      r.getKind() instanceof Raw::SubpKindProcedure and result = "generic_procedure_renaming"
      or
      r.getKind() instanceof Raw::SubpKindFunction and result = "generic_function_renaming"
    )
  }

  /** Gets the most specific filter kind of defining name `dn`. */
  string kind(Raw::DefiningName dn) {
    result = declKind(declOf(dn)) and
    not dn.getName() instanceof Raw::StringLiteral and
    not dn.getName() instanceof Raw::CharLiteral
  }

  /** Gets the identifier `dn` declares: the last component of a child unit's name (`Message` in `GPR2.Message`). */
  string identifier(Raw::DefiningName dn) {
    result = dn.getName().getText().regexpCapture("(?:.*\\.)?([^.]+)", 1)
  }

  /** Holds if filter kind `k` applies to `dn`: its own kind, or one above it. */
  predicate appliesTo(Raw::DefiningName dn, string k) { parentKind*(kind(dn), k) }

  /** Gets the declaration `dn` is the name of, among those `kind` classifies. */
  private Raw::BasicDecl declOf(Raw::DefiningName dn) {
    dn = result.(Raw::ExceptionHandler).getExceptionName()
    or
    not result instanceof Raw::ExceptionHandler and dn = result.getADefiningName()
  }

  /** Holds if `scope` makes what is declared in it local: anything but a package. */
  private predicate isLocalScope(Raw::AdaNode scope) {
    scope instanceof Raw::BaseSubpBody or
    scope instanceof Raw::SubpSpec or
    scope instanceof Raw::EntrySpec or
    scope instanceof Raw::TaskBody or
    scope instanceof Raw::TaskDef or
    scope instanceof Raw::EntryBody or
    scope instanceof Raw::ProtectedDef or
    scope instanceof Raw::ProtectedBody or
    scope instanceof Raw::BlockStmt or
    scope instanceof Raw::BaseLoopStmt or
    scope instanceof Raw::ExceptionHandler
  }

  /**
   * Gets the location of `dn`: `unit` for the name of a compilation unit, `global` if
   * declared in packages only (generic ones included), else `local`.
   */
  string location(Raw::DefiningName dn) {
    exists(kind(dn)) and
    exists(Raw::BasicDecl d | d = declOf(dn) |
      d.getParent() instanceof Raw::LibraryItem and result = "unit"
      or
      not d.getParent() instanceof Raw::LibraryItem and
      if isLocalScope(d.getParent+()) then result = "local" else result = "global"
    )
  }

  /**
   * A naming convention: `rule(kind, pattern, positive, caseSensitive)` says that names
   * of filter kind `kind` must match `pattern` (one of the positive patterns of the
   * kind, if it has any), or must not (`positive = false`).
   */
  signature predicate ruleSig(string kind, string pattern, boolean positive, boolean caseSensitive);

  module Convention<ruleSig/4 rule> {
    /** Holds if `name` matches `pattern` somewhere, as AdaControl's patterns do. */
    bindingset[name, pattern, caseSensitive]
    private predicate matchesPattern(string name, string pattern, boolean caseSensitive) {
      caseSensitive = true and exists(name.regexpFind(pattern, _, _))
      or
      caseSensitive = false and exists(name.regexpFind("(?i)" + pattern, _, _))
    }

    /**
     * Holds if the name of `dn` breaks the convention for kind `k`: it matches none of
     * the positive patterns of `k`, or matches a negative one, which is `pattern`.
     */
    predicate violates(Raw::DefiningName dn, string k, string pattern) {
      appliesTo(dn, k) and
      exists(string name | name = identifier(dn) |
        rule(k, _, true, _) and
        not exists(string p, boolean cs | rule(k, p, true, cs) and matchesPattern(name, p, cs)) and
        pattern = concat(string p | rule(k, p, true, _) | p, " or ")
        or
        exists(boolean cs | rule(k, pattern, false, cs) and matchesPattern(name, pattern, cs))
      )
    }
  }
}
