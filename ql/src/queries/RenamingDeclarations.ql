/**
 * @name Renaming in the scope of the renamed entity
 * @description A renaming declared in the same declarative part as the entity it renames
 *              gives the same visibility under a second name: a pure synonym, which makes
 *              the reader wonder whether two entities are meant. AdaControl rule
 *              `Renaming_Declarations` with `synonym all`. Other filters, kinds and places
 *              are in `codeql.ada.adacontrol.RenamingDeclarations` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/renaming-declarations
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability readability adacontrol
 */

import ada
import codeql.ada.adacontrol.RenamingDeclarations

from BasicDecl d
where RenamingDeclarations::hasFilter(d, "synonym") and d.fromSource()
select d,
  d.getAName() + " renames $@, declared in the same declarative part: it is only a synonym.",
  RenamingDeclarations::renamed(d), RenamingDeclarations::renamed(d).getAName()
