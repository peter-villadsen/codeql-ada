/**
 * Every keyword of `codeql.ada.adacontrol.Statements`, for the shipped query's test
 * sources (`any_statement` aside), and `exception_others`.
 */

import ada
import codeql.ada.adacontrol.Statements

from AdaNode s, string kw
where
  s.fromSource() and
  (
    Statements::statement(s, kw) and kw != "any_statement"
    or
    Statements::othersHandler(s, kw)
  )
select s, kw
