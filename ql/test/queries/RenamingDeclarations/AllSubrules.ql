/**
 * Every predicate of `codeql.ada.adacontrol.RenamingDeclarations`, for the shipped
 * query's test sources: each renaming's kind, filters and places.
 */

import ada
import codeql.ada.adacontrol.RenamingDeclarations
import codeql.ada.adacontrol.Places

from BasicDecl d, string what
where
  d.fromSource() and
  (
    what = "kind " + RenamingDeclarations::kind(d)
    or
    exists(string f | RenamingDeclarations::hasFilter(d, f) | what = "filter " + f)
    or
    RenamingDeclarations::isRenaming(d) and
    exists(string place | Places::isAt(d, place) | what = "place " + place)
  )
select d, what
