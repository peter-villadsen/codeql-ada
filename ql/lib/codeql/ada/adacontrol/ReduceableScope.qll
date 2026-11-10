/**
 * AdaControl rule `Reduceable_Scope`: declarations that could be moved to an inner
 * scope, because every reference to them is in it, or from a package spec to its body
 * (`docs/adacontrol.md`).
 *
 * The scopes (`isScope`) are subprogram, entry, task and package bodies, and block
 * statements. A declaration is in the scope whose declarative part declares it, or in
 * a package spec (`region`). Its references (`reference`) are the names that resolve to
 * it, outside its own declarations (a subprogram's spec and body, a type's partial and
 * full views). A reference is in a scope when it is in its declarations or statements:
 * a reference in a nested subprogram's parameter profile is not in that subprogram.
 *
 * As in AdaControl, initialized objects and constants are never moved to an inner
 * scope (the initialization is a use at the declaration), nor task objects, nor
 * entities whose `'Access` or `'Address` is taken, nor primitive operations of tagged
 * types. Further, a variable is moved only into a block or a package body, and not
 * into a loop: in a subprogram or a loop it would no longer keep its value from one
 * call, or iteration, to the next.
 */

private import codeql.ada.ast.internal.Raw
private import codeql.ada.Subprograms
private import codeql.ada.Declarations
private import codeql.ada.adacontrol.DirectlyAccessedGlobals
private import codeql.ada.adacontrol.TypeCategories
private import codeql.ada.adacontrol.Unresolved

module ReduceableScope {
  /** Holds if `s` is a scope declarations can move to; `isBlock` says whether it is a block statement. */
  predicate isScope(Raw::AdaNode s, boolean isBlock) {
    (
      s instanceof Raw::SubpBody or
      s instanceof Raw::EntryBody or
      s instanceof Raw::TaskBody or
      s instanceof Raw::PackageBody
    ) and
    isBlock = false
    or
    s instanceof Raw::BlockStmt and isBlock = true
  }

  /** Gets the declarations or the statements of scope `s`. */
  private Raw::AdaNode part(Raw::AdaNode s) {
    isScope(s, _) and
    (
      result = s.(Raw::SubpBody).getDecls() or
      result = s.(Raw::SubpBody).getStmts() or
      result = s.(Raw::EntryBody).getDecls() or
      result = s.(Raw::EntryBody).getStmts() or
      result = s.(Raw::TaskBody).getDecls() or
      result = s.(Raw::TaskBody).getStmts() or
      result = s.(Raw::PackageBody).getDecls() or
      result = s.(Raw::PackageBody).getStmts() or
      result = s.(Raw::DeclBlock).getDecls() or
      result = s.(Raw::DeclBlock).getStmts() or
      result = s.(Raw::BeginBlock).getStmts()
    )
  }

  /** Holds if `n` is in the declarations or statements of scope `s`. */
  predicate inScope(Raw::AdaNode n, Raw::AdaNode s) { n.getParent+() = part(s) }

  /** Gets the declaration that places entity `e`: its object declaration, or itself. */
  private Raw::BasicDecl declarationNode(Raw::AdaNode e) {
    result = e.(Variable).getDeclaration()
    or
    e = result.(Raw::ExceptionDecl).getIds().getChild(_)
    or
    result = e
  }

  /**
   * Gets the region entity `e` is declared in: the scope, or the package spec, whose
   * declarative part declares it.
   */
  Raw::AdaNode region(Raw::AdaNode e) {
    exists(Raw::DeclarativePart dp |
      declarationNode(e).getParent().getParent() = dp and
      not dp.getParent+() instanceof Raw::GenericFormalPart
    |
      result = dp.getParent() and isScope(result, _) and dp = part(result)
      or
      result = dp.getParent() and
      result instanceof Raw::BasePackageDecl and
      (dp instanceof Raw::PublicPart or dp instanceof Raw::PrivatePart)
    )
  }

  /** Holds if entity `e` is exported (`Export` aspect or pragma): code outside Ada may use it. */
  private predicate isExported(Raw::AdaNode e) {
    exists(Raw::BasicDecl d |
      d = [e.(Subprogram).getADeclaration(), e.(Variable).getDeclaration()] or d = e
    |
      exists(Raw::AspectAssoc a | a = d.getAspects().getAspectAssocs().getChild(_) |
        a.getId().(Raw::Name).getText().toLowerCase() = "export" and
        not a.getExpr().(Raw::Name).getText().toLowerCase() = "false"
      )
      or
      exists(Raw::PragmaNode p |
        p.getId().getValue().toLowerCase() = "export" and
        p.getArgs().getChild(_).(Raw::PragmaArgumentAssoc).getExpr().(Raw::Name).getReferencedDecl() = d
      )
    )
  }

  /** Holds if `s` is a primitive operation of a tagged type, or overrides one. */
  private predicate isDispatching(Subprogram s) {
    exists(Type t | s.isPrimitiveOf(t, _)) or s.overrides(_)
  }

  /**
   * Gets the category of entity `e`: `variable`, `constant`, `subprogram`, `type`,
   * `package`, `exception` or `generic`.
   */
  string category(Raw::AdaNode e) {
    e.fromSource() and
    exists(region(e)) and
    not isExported(e) and
    (
      exists(Variable v | v = e and not v.isRenaming() |
        if v.isConstant() then result = "constant" else result = "variable"
      ) and
      not TypeCategories::category(e.(Variable).getType(), true) = "task"
      or
      exists(Subprogram s | s = e and not s.isGeneric() and not isDispatching(s)) and
      result = "subprogram"
      or
      e instanceof Type and
      not e = TypeCategories::fullView(_) and
      not e instanceof Raw::TaskTypeDecl and
      not e instanceof Raw::ProtectedTypeDecl and
      result = "type"
      or
      e instanceof Raw::BasePackageDecl and not e instanceof Raw::GenericPackageInternal and result = "package"
      or
      e = any(Raw::ExceptionDecl d).getIds().getChild(_) and result = "exception"
      or
      (e instanceof Raw::GenericSubpDecl or e instanceof Raw::GenericPackageDecl) and
      result = "generic"
    )
  }

  /** Gets a declaration of entity `e` that names resolve to. */
  private Raw::BasicDecl declarationOf(Raw::AdaNode e) {
    result = e.(Subprogram).getADeclaration()
    or
    exists(Type t | t = e | result = t or result = TypeCategories::fullView(t))
    or
    result = declarationNode(e) and not e instanceof Subprogram and not e instanceof Type
    or
    // an entity of a package stands for the package
    exists(Raw::BasePackageDecl p | p = e and category(e) = "package" | result.getParent+() = p)
  }

  /** Gets a declaration of `e` that is a region references inside do not count: its spec and body. */
  private Raw::AdaNode ownNode(Raw::AdaNode e) {
    result = declarationOf(e) and not e instanceof Variable and not e instanceof Raw::DefiningName
    or
    result = declarationNode(e) and category(e) = "package"
    or
    exists(Raw::BasicDecl d | d = declarationOf(e) and ada_body_part(d, result))
    or
    exists(Raw::BasicDecl d | d = declarationOf(e) and ada_body_part(d.getParent(), result))
  }

  /** Gets the name of entity `e`, in lower case. */
  private string lowerName(Raw::AdaNode e) {
    result = e.(Raw::DefiningName).getName().getText().toLowerCase()
    or
    result = e.(Raw::BasicDecl).getAName().toLowerCase()
  }

  /**
   * Gets a name that refers to entity `e`, outside its own declarations: one that
   * resolves to it, or an identifier spelled like it that did not resolve, in its
   * region (or the body of its package spec), which may be a reference extraction
   * could not resolve.
   */
  Raw::Name reference(Raw::AdaNode e) {
    exists(category(e)) and
    (
      Unresolved::identifier(result, lowerName(e)) and
      (result.getParent+() = region(e) or result.getParent+() = bodyOf(region(e)))
      or
      result = e.(Variable).getAnAccess()
      or
      not e instanceof Variable and
      result.getReferencedDecl() = declarationOf(e) and
      (
        not e instanceof Raw::DefiningName
        or
        result.getText().toLowerCase() = e.(Raw::DefiningName).getName().getText().toLowerCase()
      )
    ) and
    not result.getParent*() = ownNode(e)
  }

  /** Holds if the `'Access`, `'Address` or the like of `e` is taken. */
  private predicate isAliased(Raw::AdaNode e) { DirectlyAccessedGlobals::isAliased(reference(e)) }

  /** Holds if `e` may move to an inner scope at all. */
  private predicate isMovable(Raw::AdaNode e) {
    exists(category(e)) and
    not isAliased(e) and
    not exists(e.(Variable).getInitializer()) and
    not category(e) = "constant"
  }

  /** Holds if scope `s` is not a block, or blocks are targets (`blocks` = true). */
  bindingset[blocks]
  private predicate allowed(Raw::AdaNode s, boolean blocks) {
    isScope(s, false) or blocks = true and isScope(s, true)
  }

  /** Holds if every reference to `e` is in scope `s`, strictly inside the region of `e`. */
  private predicate allIn(Raw::AdaNode e, Raw::AdaNode s) {
    isMovable(e) and
    isScope(s, _) and
    inScope(s, region(e)) and
    exists(reference(e)) and
    forall(Raw::Name r | r = reference(e) | inScope(r, s))
  }

  /**
   * Holds if a variable `e`, moved to `s`, would no longer keep its value: `s` is, or is
   * in, a body other than a package's, or in a loop, inside the region of `e`.
   */
  private predicate changesLifetime(Raw::AdaNode e, Raw::AdaNode s) {
    category(e) = "variable" and
    exists(Raw::AdaNode mid |
      mid = s.getParent*() and
      inScope(mid, region(e))
    |
      mid instanceof Raw::BaseSubpBody or
      mid instanceof Raw::EntryBody or
      mid instanceof Raw::TaskBody or
      mid instanceof Raw::BaseLoopStmt
    )
  }

  /**
   * Holds if entity `e` could be declared in scope `s`, the innermost scope holding
   * every reference to it; with `blocks` false, block statements are not targets
   * (AdaControl's `no_blocks`).
   */
  predicate innerScope(Raw::AdaNode e, Raw::AdaNode s, boolean blocks) {
    blocks = [false, true] and
    allIn(e, s) and
    allowed(s, blocks) and
    not changesLifetime(e, s) and
    not exists(Raw::AdaNode inner |
      allIn(e, inner) and allowed(inner, blocks) and not changesLifetime(e, inner) and inScope(inner, s)
    )
  }

  /** Gets the body of package spec `p`. */
  private Raw::PackageBody bodyOf(Raw::BasePackageDecl p) {
    ada_body_part(p, result) or ada_body_part(p.getParent(), result)
  }

  /** Holds if constant `e` is, or completes, a deferred constant: its name is declared twice in its package spec. */
  private predicate isDeferred(Variable e) {
    exists(Variable other |
      other != e and
      other.getName().toLowerCase() = e.getName().toLowerCase() and
      region(other) = region(e)
    )
  }

  /**
   * `to_body`: entity `e`, declared in package spec `p`, is referenced only in the body
   * of `p`, where it could be declared.
   */
  predicate toBody(Raw::AdaNode e, Raw::BasePackageDecl p) {
    p = region(e) and
    exists(category(e)) and
    not isAliased(e) and
    not isDeferred(e) and
    exists(reference(e)) and
    forall(Raw::Name r | r = reference(e) | r.getParent+() = bodyOf(p))
  }

  /**
   * Holds if entity `e`, declared in a scope (not a package spec), is never referenced.
   * Not reported: entities marked `Unreferenced`, and objects initialized by a call.
   */
  predicate unused(Raw::AdaNode e) {
    exists(category(e)) and
    // `with Unreferenced`, `pragma Unreferenced`: declared unused on purpose
    not declarationNode(e).isMarkedUnreferenced() and
    // an object initialized by a call is kept for the call's effect
    not exists(Raw::AdaNode c | c.getParent*() = e.(Variable).getInitializer() |
      c instanceof Raw::CallExpr or c.(Raw::Name).getReferencedDecl() instanceof Subprogram
    ) and
    isScope(region(e), _) and
    not exists(reference(e))
  }
}
