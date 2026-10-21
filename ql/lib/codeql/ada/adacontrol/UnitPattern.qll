/**
 * AdaControl rule `Unit_Pattern`: usage patterns of units: one tagged type per package,
 * tagged type hierarchies following the unit hierarchy, the order of context clauses and
 * of declarations (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.Dependencies
private import codeql.ada.adacontrol.Derivations

module UnitPattern {
  /** Gets the package spec that directly declares tagged type `t`, in its visible or private part. */
  private Raw::BasePackageDecl packageOf(Type t) {
    t = result.getPublicPart().getDecls().getChild(_) or
    t = result.getPrivatePart().getDecls().getChild(_)
  }

  /** Holds if `t` is a tagged type declared by its own definition: not a private view's full view. */
  private predicate isTaggedDeclaration(Type t) {
    t.isTagged() and
    not exists(Type partial |
      partial.isPrivate() and
      partial.getQualifiedName() = t.getQualifiedName() and
      partial != t
    )
  }

  /** `single_tagged_type`: package `p` declares tagged type `t` after another one, `first`. */
  predicate secondTaggedType(Raw::BasePackageDecl p, Type t, Type first) {
    isTaggedDeclaration(t) and
    isTaggedDeclaration(first) and
    p = packageOf(t) and
    p = packageOf(first) and
    first.getLocation().getStartLine() < t.getLocation().getStartLine()
  }

  /**
   * `tagged_type_hierarchy`: type extension `t`'s parent `parent` is not declared in the
   * parent unit of `t`'s unit (nor in `t`'s own unit).
   */
  predicate breaksHierarchy(Type t, Type parent) {
    exists(t.getDefinition().(Raw::DerivedTypeDef).getRecordExtension()) and
    parent = Derivations::aParent(t) and
    parent.isTagged() and
    exists(string unit, string parentUnit |
      unit = Dependencies::unitName(t.getEnclosingUnit()).toLowerCase() and
      parentUnit = Dependencies::unitName(parent.getEnclosingUnit()).toLowerCase() and
      not unit = parentUnit and
      not unit.regexpCapture("(.*)\\.[^.]+", 1) = parentUnit
    )
  }

  /** Gets the kind of context clause `c`: `with`, `use`, `use_type`, `use_all_type`, `pragma`. */
  string clauseKind(Raw::AdaNode c) {
    c instanceof Raw::WithClause and result = "with"
    or
    c instanceof Raw::UsePackageClause and result = "use"
    or
    c instanceof Raw::UseTypeClause and
    if c.(Raw::UseTypeClause).getHasAll() instanceof Raw::AllPresent
    then result = "use_all_type"
    else result = "use_type"
    or
    c instanceof Raw::PragmaNode and result = "pragma"
  }

  /**
   * An order of elements: `group(kind)` is the 0-based position of the group the kind
   * belongs to (a kind may be in several groups); kinds in no group are not allowed.
   */
  signature int groupSig(string kind);

  /**
   * `context_clauses_order` (with the kinds of `clauseKind`) and `declarations_order`
   * (with the kinds of `declarationKind`): `Order<group>::outOfOrder(list, e)` holds when
   * element `e` of `list` cannot follow the elements before it.
   */
  module Order<groupSig/1 group> {
    /** Gets the kind of element `e`: a context clause or a declaration. */
    private string kindOf(Raw::AdaNode e) { result = [clauseKind(e), declarationKind(e)] }

    /**
     * Holds if element `e` of `list` is not allowed where it is: its kind is in no group,
     * or in no group at or after the first group of an element before it. (An element
     * whose kind is in several groups is taken at its first group.)
     */
    predicate outOfOrder(Raw::AdaNodeList list, Raw::AdaNode e) {
      exists(int i | e = list.getChild(i) |
        not exists(group(kindOf(e)))
        or
        exists(Raw::AdaNode before, int j |
          before = list.getChild(j) and
          j < i and
          not exists(int g | g = group(kindOf(e)) and g >= min(group(kindOf(before))))
        )
      )
    }
  }

  /** Gets the context clause list of compilation unit `cu`. */
  Raw::AdaNodeList contextClauses(Raw::CompilationUnit cu) { result = cu.getPrelude() }

  /** Gets the declaration list of `target` part `kind`: `package_public`, `package_private`, `package_body`, `subprogram`. */
  Raw::AdaNodeList declarations(Raw::AdaNode part, string kind) {
    result = part.(Raw::BasePackageDecl).getPublicPart().getDecls() and kind = "package_public"
    or
    result = part.(Raw::BasePackageDecl).getPrivatePart().getDecls() and kind = "package_private"
    or
    result = part.(Raw::PackageBody).getDecls().getDecls() and kind = "package_body"
    or
    result = [part.(Raw::SubpBody).getDecls(), part.(Raw::EntryBody).getDecls()].getDecls() and
    kind = "subprogram"
  }

  /** Gets the kind of declaration `d`, as `declarations_order` names it. */
  string declarationKind(Raw::AdaNode d) {
    d instanceof Raw::UsePackageClause and result = "use"
    or
    d instanceof Raw::UseTypeClause and
    if d.(Raw::UseTypeClause).getHasAll() instanceof Raw::AllPresent
    then result = "use_all_type"
    else result = "use_type"
    or
    d instanceof Raw::NumberDecl and result = "number"
    or
    exists(Raw::ObjectDecl o | o = d |
      exists(o.getRenamingClause()) and result = "object_renaming"
      or
      not exists(o.getRenamingClause()) and
      if o.getHasConstant() instanceof Raw::ConstantPresent
      then result = "constant"
      else result = "variable"
    )
    or
    d.(Type).isPrivate() and result = "private_type"
    or
    d instanceof Raw::TypeDecl and not d.(Type).isPrivate() and result = "full_type"
    or
    d instanceof Raw::IncompleteTypeDecl and result = "full_type"
    or
    d instanceof Raw::SubtypeDecl and result = "subtype"
    or
    (d instanceof Raw::SubpDecl or d instanceof Raw::AbstractSubpDecl) and result = "subprogram_spec"
    or
    (d instanceof Raw::ExprFunction or d instanceof Raw::NullSubpDecl) and
    if ada_body_part(_, d) then result = "subprogram_body" else result = "subprogram_spec"
    or
    d instanceof Raw::SubpBody and result = "subprogram_body"
    or
    d instanceof Raw::PackageDecl and result = "package_spec"
    or
    d instanceof Raw::PackageBody and result = "package_body"
    or
    d instanceof Raw::GenericSubpDecl and result = "generic_subprogram_spec"
    or
    d instanceof Raw::GenericPackageDecl and result = "generic_package_spec"
    or
    (d instanceof Raw::TaskTypeDecl or d instanceof Raw::SingleTaskDecl) and result = "task_spec"
    or
    (d instanceof Raw::ProtectedTypeDecl or d instanceof Raw::SingleProtectedDecl) and
    result = "protected_spec"
    or
    d instanceof Raw::TaskBody and result = "task_body"
    or
    d instanceof Raw::ProtectedBody and result = "protected_body"
    or
    d instanceof Raw::SubpRenamingDecl and result = "subprogram_renaming"
    or
    d instanceof Raw::PackageRenamingDecl and result = "package_renaming"
    or
    exists(d.(Raw::ExceptionDecl).getRenames()) and result = "exception_renaming"
    or
    d instanceof Raw::ExceptionDecl and not exists(d.(Raw::ExceptionDecl).getRenames()) and
    result = "exception"
    or
    d instanceof Raw::GenericSubpInstantiation and result = "subprogram_instantiation"
    or
    d instanceof Raw::GenericPackageInstantiation and result = "package_instantiation"
  }
}
