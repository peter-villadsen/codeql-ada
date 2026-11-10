/**
 * Every condition of `codeql.ada.adacontrol.GenericAliasing`, for the shipped query's
 * test sources.
 */

import ada
import codeql.ada.adacontrol.GenericAliasing

from Raw::GenericInstantiation inst, int i, int j, string kind, string condition
where inst.fromSource() and GenericAliasing::aliasing(inst, i, j, kind, condition)
select inst, i, j, kind, condition
