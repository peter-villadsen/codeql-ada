/**
 * @name Unfinished or empty declaration
 * @description A subprogram whose only statement calls itself (the body `gnatstub`
 *              generates) recurses forever; a package spec with an empty private part
 *              says `private` for nothing. AdaControl rule `Declarations`, keywords
 *              `self_calling_function`, `self_calling_procedure` and
 *              `empty_private_part`, at all places. About a hundred more keywords, and
 *              the places, are in `codeql.ada.adacontrol.Declarations` and
 *              `codeql.ada.adacontrol.Places` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/declarations
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags maintainability correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.Declarations

from AdaNode d, string kw, string msg
where
  Declarations::declaration(d, kw) and
  d.fromSource() and
  (
    kw = "self_calling_function" and
    msg = "This function only calls itself, so it never returns: an unfinished stub?"
    or
    kw = "self_calling_procedure" and
    msg = "This procedure only calls itself, so it never returns: an unfinished stub?"
    or
    kw = "empty_private_part" and
    msg = "This package has an empty private part."
  )
select d, msg
