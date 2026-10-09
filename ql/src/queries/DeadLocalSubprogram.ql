/**
 * @name Dead local subprogram
 * @description A subprogram nested inside another subprogram that is never called and
 *              whose address is never taken is dead code. Not reported when its name
 *              appears, unresolved, in the enclosing body: that may be a call extraction
 *              could not resolve, usually because of a missing dependency (D-026).
 * @id ada/dead-local-subprogram
 * @kind problem
 * @problem.severity warning
 * @tags maintainability dead-code
 */

import ada

/**
 * Holds if some name refers to a declaration of `s` (its spec, stub or body) other
 * than its own closing `end <name>;`: a call, `'Access`, a generic actual, a renaming.
 * A body's `end` name is extracted as two self-references, the `EndName` and the
 * `Identifier` inside it, so both are left out.
 */
private predicate isReferenced(Subprogram s) {
  exists(Name n |
    n.getReferencedDecl() = s.getADeclaration() and
    not n instanceof EndName and
    not n.getParent() instanceof EndName
  )
}

/** Holds if `s` is declared `overriding`: it is called by dispatching, never by name. */
private predicate isOverriding(Subprogram s) {
  s.getADeclaration().(ClassicSubpDecl).getOverriding() instanceof OverridingOverriding or
  s.getADeclaration().(BaseSubpBody).getOverriding() instanceof OverridingOverriding
}

/**
 * Holds if an instantiation in `enclosing` may use `s` without naming it: as the
 * default of a generic formal subprogram of the same name (`with function Compare
 * (...) is <>`), or as an actual that did not resolve (`"=" => "="`).
 */
private predicate mayBeUsedByInstantiation(Subprogram s, BaseSubpBody enclosing) {
  exists(GenericInstantiation inst | inst.getParent+() = enclosing |
    exists(FormalSubpDecl f |
      f.getDefaultExpr() instanceof BoxExpr and
      f.getSubpSpec().getSubpName().getName().getText().toLowerCase() = s.getName().toLowerCase() and
      f.getParent+() = inst.getDesignatedGeneric()
    )
    or
    exists(Name actual |
      actual = inst.getChild(_).(AssocList).getChild(_).(ParamAssoc).getRExpr() and
      not exists(actual.getReferencedDecl()) and
      actual.getText().toLowerCase() = s.getName().toLowerCase()
    )
  )
}

from Subprogram s, SubpBody body, BaseSubpBody enclosing
where
  body = s.getBody() and
  // nested: the subprogram is declared inside another subprogram's body
  enclosing = s.getParent+() and
  not isReferenced(s) and
  // A same-named call that did not resolve may be a call (missing dependencies, D-026).
  // Checking every enclosing body amounts to checking the innermost one.
  not s.hasUnresolvedNamesakeIn(enclosing) and
  not isOverriding(s) and
  not mayBeUsedByInstantiation(s, enclosing) and
  s.fromSource()
select body, "This nested subprogram is never called."
