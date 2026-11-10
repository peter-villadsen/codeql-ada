/**
 * AdaControl rule `Usage`: how the entities of a class are used -- objects read,
 * written, initialized; types used; subprograms called or accessed; exceptions raised
 * or handled; tasks called or aborted; protected objects called; generics
 * instantiated -- and where they are declared (`docs/adacontrol.md`).
 *
 * An entity is a declaration of the source (`entityClass`); `holds(e, keyword)` is
 * what is known about it, for the usage keywords and the places `from_visible`,
 * `from_private` and `from_spec`. A reference that writes is an assignment target, an
 * `out` or `in out` actual, or a part of one (`DirectlyAccessedGlobals::written`); a
 * reference that is not only written reads. The prefix of `'Access`, `'Address` and
 * the like counts as reading and writing: what happens through the alias is not
 * followed.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Calls
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.DirectlyAccessedGlobals
private import codeql.ada.adacontrol.TypeCategories
private import codeql.ada.adacontrol.Unresolved

module Usage {
  /** Holds if type `t` is the entity for its type: not the full view of a partial view. */
  private predicate isTypeEntity(Type t) { not t = TypeCategories::fullView(_) }

  /** Holds if `s` is a regular subprogram: not an operation of a task or protected type. */
  private predicate isRegularSubprogram(Subprogram s) {
    not s.getParent+() instanceof Raw::ProtectedDef and
    not s.getParent+() instanceof Raw::ProtectedBody and
    not s.getParent+() instanceof Raw::TaskDef
  }

  /**
   * Gets the class of entity `e`: `variable`, `constant`, `in_parameter`,
   * `out_parameter`, `in_out_parameter`, `type`, `procedure`, `function`,
   * `exception`, `task`, `protected` or `generic`.
   */
  string entityClass(Raw::AdaNode e) {
    e.fromSource() and
    (
      exists(Variable v | v = e and not v.isLoopVariable() |
        if v.isConstant() then result = "constant" else result = "variable"
      )
      or
      exists(Parameter p | p = e and p.getSubprogram().fromSource() |
        p.getMode() = "in" and result = "in_parameter"
        or
        p.getMode() = "out" and result = "out_parameter"
        or
        p.getMode() = "in out" and result = "in_out_parameter"
      )
      or
      isTypeEntity(e) and
      not e instanceof Raw::TaskTypeDecl and
      not e instanceof Raw::ProtectedTypeDecl and
      result = "type"
      or
      exists(Subprogram s | s = e and isRegularSubprogram(s) and not s.isGeneric() |
        s.isProcedure() and result = "procedure"
        or
        s.isFunction() and result = "function"
      )
      or
      e = any(Raw::ExceptionDecl d | not exists(d.getRenames())).getIds().getChild(_) and
      result = "exception"
      or
      (
        e instanceof Raw::SingleTaskDecl
        or
        e instanceof Raw::TaskTypeDecl and not e instanceof Raw::SingleTaskTypeDecl
      ) and
      result = "task"
      or
      (e instanceof Raw::SingleProtectedDecl or e instanceof Raw::ProtectedTypeDecl) and
      result = "protected"
      or
      (e instanceof Raw::GenericSubpDecl or e instanceof Raw::GenericPackageDecl) and
      result = "generic"
    )
  }

  /** Holds if `cls`, a class given to the rule, covers entity `e` (`object` is variables and constants, `all` everything). */
  bindingset[cls]
  predicate inClass(Raw::AdaNode e, string cls) {
    entityClass(e) = cls.toLowerCase()
    or
    cls.toLowerCase() = "object" and entityClass(e) = ["variable", "constant"]
    or
    cls.toLowerCase() = "all" and exists(entityClass(e))
  }

  /** Gets the name of entity `e`. */
  string entityName(Raw::AdaNode e) {
    result = e.(Variable).getName() or
    result = e.(Parameter).getName() or
    result = e.(Raw::DefiningName).getName().getText() and
    not e instanceof Variable and
    not e instanceof Parameter
    or
    result = e.(Raw::BasicDecl).getADefiningName().getName().getText()
    or
    result = e.(Raw::SingleTaskDecl).getTaskType().getADefiningName().getName().getText()
  }

  /** Gets a name that refers to object or parameter `e`. */
  private Raw::Name objectAccess(Raw::AdaNode e) {
    result = e.(Variable).getAnAccess() or result = e.(Parameter).getAnAccess()
  }

  /** Holds if `n` is the prefix of `'Access`, `'Address` and the like, or of a part of it. */
  private predicate isAliased(Raw::Name n) {
    DirectlyAccessedGlobals::isAliased(n) or
    exists(Raw::DottedName d | n = d.getPrefix() | isAliased(d))
  }

  /** Gets a declaration entity `e` is declared by, that names resolve to. */
  private Raw::BasicDecl declarationOf(Raw::AdaNode e) {
    result = e.(Subprogram).getADeclaration()
    or
    exists(Type t | t = e | result = t or result = TypeCategories::fullView(t))
    or
    result = e.(Raw::BasicDecl) and not e instanceof Subprogram and not e instanceof Type
    or
    e = result.(Raw::ExceptionDecl).getIds().getChild(_)
  }

  /** Gets a name referring to entity `e`, outside its own declarations. */
  private Raw::Name reference(Raw::AdaNode e) {
    exists(Raw::BasicDecl d | d = declarationOf(e) |
      result.getReferencedDecl() = d and
      not result.getParent*() = d and
      (
        e instanceof Raw::DefiningName and
        result.getText().toLowerCase() = entityName(e).toLowerCase()
        or
        not e instanceof Raw::DefiningName
      )
    )
    or
    result = objectAccess(e)
  }

  /** Holds if `e` is declared in the visible part (`visible` = true) or private part (false) of a package spec. */
  private predicate inPackageSpec(Raw::AdaNode e, boolean visible) {
    exists(Raw::DeclarativePart p |
      p = e.getParent+() and
      not exists(Raw::DeclarativePart inner | inner = e.getParent+() and inner.getParent+() = p) and
      p.getParent() instanceof Raw::BasePackageDecl
    |
      p instanceof Raw::PublicPart and visible = true
      or
      p instanceof Raw::PrivatePart and visible = false
    )
  }

  /** Holds if the task entity `e` (a single task or a task type) is denoted by `n`, an object of it. */
  private predicate denotesTask(Raw::Name n, Raw::AdaNode e) {
    n.getReferencedDecl() = e
    or
    exists(Variable v | n = v.getAnAccess() and v.getType() = e)
  }

  /** Holds if `n` calls an operation (entry or subprogram) declared in task or protected entity `e`, from outside it. */
  private predicate callsOperation(Raw::Name n, Raw::AdaNode e) {
    exists(Raw::BasicDecl op |
      op = n.getReferencedDecl() and
      op.getParent+() = e and
      (op instanceof Raw::EntryDecl or op instanceof Raw::BasicSubpDecl) and
      not n.getParent() instanceof Raw::AttributeRef and
      not n.getParent*() = e and
      not exists(Raw::AdaNode body | n.getParent+() = body and ada_body_part(e, body))
    )
  }

  /**
   * Holds if usage `keyword` holds of entity `e`: `read`, `written`, `initialized`,
   * `used`, `called`, `accessed`, `raised`, `handled`, `aborted`, `instantiated`, or a
   * place, `from_visible`, `from_private`, `from_spec`.
   */
  predicate holds(Raw::AdaNode e, string keyword) {
    exists(entityClass(e)) and
    (
      // an identifier that did not resolve, spelled like the object, in its unit: maybe
      // a use, which may read and write
      exists(Raw::Identifier i |
        Unresolved::identifier(i, entityName(e).toLowerCase()) and
        i.getEnclosingUnit() = e.getEnclosingUnit() and
        (e instanceof Variable or e instanceof Parameter)
      ) and
      keyword = ["read", "written"]
      or
      exists(Raw::Name n | n = objectAccess(e) |
        keyword = "read" and
        (
          DirectlyAccessedGlobals::written(n, true) or
          not DirectlyAccessedGlobals::written(n, _) or
          isAliased(n)
        )
        or
        keyword = "written" and (DirectlyAccessedGlobals::written(n, _) or isAliased(n))
      )
      or
      keyword = "initialized" and
      (
        exists(e.(Variable).getInitializer())
        or
        TypeCategories::category(e.(Variable).getType(), true) = "access"
        or
        exists(e.(Parameter).getDefaultExpr())
      )
      or
      keyword = "read" and entityClass(e) = "constant" and exists(reference(e))
      or
      keyword = "used" and entityClass(e) = "type" and exists(reference(e))
      or
      keyword = "called" and exists(Call c | c.getTarget() = e)
      or
      keyword = "accessed" and
      exists(Raw::AttributeRef a | a.getPrefix() = reference(e) |
        a.getAttribute().getValue().toLowerCase() =
          ["access", "unchecked_access", "unrestricted_access", "address"]
      )
      or
      keyword = "raised" and
      (
        reference(e) = [any(Raw::RaiseStmt r).getExceptionName(), any(Raw::RaiseExpr r).getExceptionName()]
        or
        exists(Raw::AttributeRef a, Call c |
          a.getPrefix() = reference(e) and
          a.getAttribute().getValue().toLowerCase() = "identity" and
          a = c.getAnArgument() and
          c.getTarget().hasName("raise_exception")
        )
      )
      or
      keyword = "handled" and
      reference(e).getParent() = any(Raw::ExceptionHandler h).getHandledExceptions()
      or
      keyword = "called" and
      entityClass(e) = ["task", "protected"] and
      exists(Raw::Name n | callsOperation(n, e))
      or
      keyword = "aborted" and
      exists(Raw::Name n | n.getParent() = any(Raw::AbortStmt a).getNames() and denotesTask(n, e))
      or
      keyword = "instantiated" and
      exists(Raw::GenericInstantiation g | g.getDesignatedGeneric() = e)
      or
      keyword = "from_visible" and inPackageSpec(e, true)
      or
      keyword = "from_private" and inPackageSpec(e, false)
      or
      keyword = "from_spec" and inPackageSpec(e, _)
    )
  }

  /** Gets the usage keywords that apply to class `cls`. */
  string keyword(string cls) {
    cls = ["variable", "in_parameter", "out_parameter", "in_out_parameter"] and
    result = ["read", "written", "initialized"]
    or
    cls = "constant" and result = "read"
    or
    cls = "type" and result = "used"
    or
    cls = ["procedure", "function"] and result = ["called", "accessed"]
    or
    cls = "exception" and result = ["raised", "handled"]
    or
    cls = "task" and result = ["called", "aborted"]
    or
    cls = "protected" and result = "called"
    or
    cls = "generic" and result = "instantiated"
  }

  /**
   * Holds if entity `e` satisfies condition `item`: a usage keyword or place, or `not`
   * and one.
   */
  bindingset[item]
  predicate satisfies(Raw::AdaNode e, string item) {
    exists(string i | i = item.toLowerCase().trim() |
      not i.matches("not %") and holds(e, i)
      or
      i.matches("not %") and exists(entityClass(e)) and not holds(e, i.suffix(4).trim())
    )
  }

  /** Gets a description of the usage of `e`: each keyword of its class, with `not` when it does not hold. */
  string description(Raw::AdaNode e) {
    result =
      concat(string k |
        k = keyword(entityClass(e))
      |
        any(string s | if holds(e, k) then s = k else s = "not " + k), ", " order by k
      )
  }
}
