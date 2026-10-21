/**
 * @name Incomplete record representation clause
 * @description A record representation clause that gives no position to some component of
 *              the record: Ada allows it, so a component added later without updating the
 *              clause is laid out by the compiler wherever it likes, unnoticed. AdaControl
 *              rule `Representation_Clauses` with `incomplete_layout`. The other kinds and
 *              attribute specifications are in
 *              `codeql.ada.adacontrol.RepresentationClauses` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/representation-clauses
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.RepresentationClauses

from RecordRepClause c
where RepresentationClauses::representation(c, "incomplete_layout") and c.fromSource()
select c, "This record representation clause does not place every component of the record."
