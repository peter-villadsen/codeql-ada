/**
 * @name Dead local subprogram
 * @description A subprogram nested inside another subprogram that is never called and
 *              whose address is never taken is dead code.
 * @id ada/dead-local-subprogram
 * @kind problem
 * @problem.severity warning
 * @tags maintainability dead-code
 */

import ada

/**
 * Gets the separate forward declaration for `body`, if any, approximated by matching name
 * text within the same declarative region - the schema has no direct decl-body link. This
 * approximation means overload sets with mixed liveness may be missed (a live overload's
 * reference makes a dead sibling with the same name look referenced too); that errs toward
 * silence, the safer direction for a "dead code" query.
 */
private Raw::SubpDecl getMatchingDecl(Raw::SubpBody body) {
  result.getParent() = body.getParent() and
  result.(BasicDecl).getAName() = body.(BasicDecl).getAName()
}

/**
 * Holds if some name outside of `target`'s own `end <name>;` resolves to `target`. A
 * body's closing `end` is extracted as *two* self-referencing `ada_xref` rows - the
 * `EndName` wrapper node and its inner `Identifier` child both resolve back to the body
 * (confirmed by inspecting the debug dump) - so a plain `isReferenced()` call is always
 * true and both forms must be filtered here.
 */
private predicate isReferencedExcludingEndName(Raw::BasicDecl target) {
  exists(Name n |
    n.getReferencedDecl() = target and
    not n instanceof Raw::EndName and
    not n.getParent() instanceof Raw::EndName
  )
}

private predicate isCalled(Raw::SubpBody body) {
  isReferencedExcludingEndName(body)
  or
  isReferencedExcludingEndName(getMatchingDecl(body))
}

/** Holds if `body`'s address is taken via a `'Access` or `'Unrestricted_Access` attribute. */
private predicate isAddressTaken(Raw::SubpBody body) {
  exists(Raw::AttributeRef ar, Raw::BasicDecl target |
    ar.getAttribute().getValue().toLowerCase() = ["access", "unrestricted_access"] and
    target = ar.getPrefix().(Name).getReferencedDecl()
  |
    target = body or target = getMatchingDecl(body)
  )
}

from Raw::SubpBody body
where
  exists(Raw::BaseSubpBody enclosing | enclosing = body.getParent+()) and
  not isCalled(body) and
  not isAddressTaken(body)
select body, "This nested subprogram is never called."
