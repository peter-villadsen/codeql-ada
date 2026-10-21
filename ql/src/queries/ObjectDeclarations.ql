/**
 * @name Variable with an address but not volatile
 * @description A variable placed at an address (a device register, shared memory) but not
 *              volatile may be cached in a register or have its reads and writes optimized
 *              away. AdaControl rule `Object_Declarations`, subrule
 *              `address_not_volatile`. The subrules `min_integer_span`, `type` and
 *              `volatile_no_address` are in `codeql.ada.adacontrol.ObjectDeclarations`
 *              for a query of your own (`docs/adacontrol.md`).
 * @id ada/object-declarations
 * @kind problem
 * @problem.severity warning
 * @precision high
 * @tags reliability correctness adacontrol
 */

import ada
import codeql.ada.adacontrol.ObjectDeclarations

from ObjectDecl d
where ObjectDeclarations::addressNotVolatile(d) and d.fromSource()
select d, d.getAName() + " has an address clause but is not volatile."
