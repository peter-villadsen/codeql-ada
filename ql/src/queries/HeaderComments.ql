/**
 * @name Missing header comment
 * @description A source file whose first compilation unit starts without any comment
 *              has no header: no description, copyright or licence notice. AdaControl
 *              rule `Header_Comments`, subrule `minimum` with 1 line. A larger minimum,
 *              and the subrule `model` (lines that follow regular expressions), are in
 *              `codeql.ada.adacontrol.HeaderComments` for a query of your own
 *              (`docs/adacontrol.md`).
 * @id ada/header-comments
 * @kind problem
 * @problem.severity recommendation
 * @precision high
 * @tags maintainability adacontrol
 */

import ada
import codeql.ada.adacontrol.HeaderComments

from CompilationUnit cu
where HeaderComments::headerLineCount(cu) < 1 and cu.fromSource()
select cu, "This file has no header comment."
