/**
 * @name Use of an unchecked access attribute
 * @description `'Unchecked_Access` and GNAT's `'Unrestricted_Access` give an access value
 *              without the accessibility check, so it can outlive what it designates.
 *              AdaControl rule `Entities` with `all 'Unchecked_Access` and
 *              `all 'Unrestricted_Access`. Uses of other entities, through renamings,
 *              of instances only, and at given places, are in
 *              `codeql.ada.adacontrol.Entities` for a query of your own
 *              (`docs/adacontrol.md`); `ada/unchecked-conversion` and
 *              `ada/unchecked-deallocation` are two fixed entities.
 * @id ada/entities
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.Entities

from AttributeRef a, string attr
where
  attr = ["Unchecked_Access", "Unrestricted_Access"] and
  Entities::usesAttribute(a, attr) and
  a.fromSource()
select a,
  "'" + attr + " skips the accessibility check: the access value may outlive " +
    a.getPrefix().getText() + "."
