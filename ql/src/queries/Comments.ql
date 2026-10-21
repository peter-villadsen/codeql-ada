/**
 * @name End of long record not named
 * @description The `end record` of a record type declaration longer than 10 lines has no
 *              comment repeating the type's name, or a comment naming something else
 *              (perhaps the type's old name). AdaControl rule `Comments`, subrule
 *              `unnamed_end_record` with 10 lines. The subrules `pattern`, `position`,
 *              `terminating` and `unnamed_begin` are in `codeql.ada.adacontrol.Comments`
 *              for a query of your own (`docs/adacontrol.md`); `ada/todo-comment` is a
 *              fixed `pattern`.
 * @id ada/comments
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.Comments

from TypeDecl t
where Comments::isUnnamedEndRecord(t, 10) and t.fromSource()
select Comments::recordDef(t),
  "The end of record " + t.getName().getName().getText() +
    " should have a comment repeating its name."
