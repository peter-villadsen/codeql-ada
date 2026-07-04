/**
 * @name Raising a predefined exception
 * @description Explicitly raising a language-defined exception (`Constraint_Error`,
 *              `Program_Error`, ...) is misleading: these exceptions are meant to signal
 *              that the run-time detected an erroneous condition, not to be raised by
 *              application code. GNATcheck: `raising_predefined_exceptions`.
 * @id ada/raise-predefined-exception
 * @kind problem
 * @problem.severity recommendation
 * @tags maintainability error-handling
 */

import ada

from Raw::RaiseStmt r, Name n, string text
where
  n = r.getExceptionName() and
  text = n.getText().toLowerCase() and
  text.regexpReplaceAll("^standard\\.", "") in
    [
      "constraint_error", "program_error", "storage_error", "tasking_error", "numeric_error"
    ]
select r, "Explicit raise of predefined exception " + n.getText() + "."
