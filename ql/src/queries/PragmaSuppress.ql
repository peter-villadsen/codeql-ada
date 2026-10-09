/**
 * @name Suppressed runtime checks
 * @description `pragma Suppress` disables the runtime checks (range, overflow,
 *              index, ...) that make Ada erroneous-execution-safe; suppressed
 *              checks turn latent bugs into undefined behavior.
 * @id ada/pragma-suppress
 * @kind problem
 * @problem.severity warning
 * @tags reliability security
 */

import ada

from PragmaNode p
where
  p.getId().getValue().toLowerCase() = "suppress" and
  p.fromSource()
select p, "pragma Suppress disables runtime checks."
