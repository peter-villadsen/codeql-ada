/**
 * @name Blanket disabling of compiler warnings
 * @description `pragma Warnings (Off)` with no further argument disables all compiler
 *              warnings for the rest of the enclosing scope, hiding future genuine issues
 *              rather than suppressing one specific, reviewed warning.
 * @id ada/warnings-off
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability auditing
 */

import ada

from Raw::PragmaNode p, Raw::BaseAssocList args, Raw::PragmaArgumentAssoc first
where
  p.getId().getValue().toLowerCase() = "warnings" and
  args = p.getArgs() and
  first = args.getChild(0) and
  first.getExpr().(Raw::Identifier).getValue().toLowerCase() = "off" and
  not exists(args.getChild(1))
select p, "pragma Warnings (Off) disables all warnings without restriction."
