/**
 * @name Unused with clause
 * @description A `with` clause names a unit no other resolved name in the file
 *              refers back to; the dependency it declares is never exercised and
 *              can be removed. (Deliberately conservative: only flags units whose
 *              declaration is present in the analyzed sources, since without it
 *              there is nothing to resolve real usages against -- most notably
 *              this does not flag standard-library units when the GNAT runtime
 *              isn't part of the analyzed source set.)
 * @id ada/unused-with-clause
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability
 */

import ada

from Raw::WithClause w, Name withName, Raw::BasicDecl pkg
where
  withName = w.getPackages().getChild(_) and
  pkg = withName.getReferencedDecl() and
  not exists(Name other |
    other != withName and
    other.getReferencedDecl() = pkg and
    other.(AdaNode).getEnclosingUnit() = withName.(AdaNode).getEnclosingUnit()
  )
select withName, "With clause for " + withName.getText() + " is never used."
