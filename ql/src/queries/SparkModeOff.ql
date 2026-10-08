/**
 * @name SPARK_Mode disabled
 * @description `pragma SPARK_Mode (Off)` turns off SPARK formal verification for
 *              its scope; code inside is no longer checked for the absence of
 *              runtime errors or contract violations that SPARK would otherwise
 *              prove, so each use deserves review.
 * @id ada/spark-mode-off
 * @kind problem
 * @problem.severity warning
 * @tags reliability security
 */

import ada

from PragmaNode p, Identifier arg
where
  p.getId().getValue().toLowerCase() = "spark_mode" and
  arg.getParent+() = p and
  arg.getValue().toLowerCase() = "off" and
  p.fromSource()
select p, "pragma SPARK_Mode (Off) disables SPARK formal verification for this scope."
