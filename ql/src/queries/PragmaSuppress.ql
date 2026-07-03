/**
 * @name Suppressed runtime checks
 * @description `pragma Suppress` disables the runtime checks (range, overflow,
 *              index, ...) that make Ada erroneous-execution-safe; suppressed
 *              checks turn latent bugs into undefined behavior.
 * @id ada/pragma-suppress
 * @kind table
 * @tags reliability security
 */

import ada

from Raw::PragmaNode p
where p.getId().getValue().toLowerCase() = "suppress"
select p, "pragma Suppress disables runtime checks."
