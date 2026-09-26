/**
 * @name Unused with clause
 * @description A `with` clause names a unit no other resolved name in the file
 *              refers back to; the dependency it declares is never exercised and
 *              can be removed. (Deliberately conservative: only flags units whose
 *              declaration resolves, since without it there is nothing to resolve
 *              real usages against. Runtime units resolve as predefined
 *              pseudo-sources, D-026, whenever a GNAT runtime is found.)
 * @id ada/unused-with-clause
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability
 */

import ada

/** Gets the simple name `withName` ends in: `Text_IO` for `Ada.Text_IO`. */
private string simpleName(Name withName) {
  result = withName.(Raw::Identifier).getValue()
  or
  result = withName.(Raw::DottedName).getSuffix().(Name).getText()
}

/**
 * Holds if `unit` contains an identifier outside `w`, spelled like the unit `withName`
 * names, that did not resolve. It may be a use that name resolution failed on (common
 * where a project's dependencies are not on disk), so `withName` is not reported.
 */
private predicate hasUnresolvedMention(Raw::CompilationUnit unit, Raw::WithClause w, Name withName) {
  exists(Raw::Identifier id |
    id.(AdaNode).getEnclosingUnit() = unit and
    not id.getParent*() = w and
    not exists(id.(Name).getReferencedDecl()) and
    id.getValue().toLowerCase() = simpleName(withName).toLowerCase()
  )
}

from Raw::WithClause w, Name withName, Raw::BasicDecl pkg
where
  withName = w.getPackages().getChild(_) and
  pkg = withName.getReferencedDecl() and
  not exists(Name other |
    // Not a name within this with clause itself: in `with Ada.Text_IO;` the
    // selector `Text_IO` also resolves to the package.
    not other.getParent*() = w and
    other.getReferencedDecl() = pkg and
    other.(AdaNode).getEnclosingUnit() = withName.(AdaNode).getEnclosingUnit()
  ) and
  not hasUnresolvedMention(withName.(AdaNode).getEnclosingUnit(), w, withName) and
  withName.(AdaNode).fromSource()
select withName, "With clause for " + withName.getText() + " is never used."
