/**
 * Every condition of `codeql.ada.adacontrol.ParameterAliasing`, with and without
 * `with_in`, for the shipped query's test sources.
 */

import ada
import codeql.ada.adacontrol.ParameterAliasing

from Call c, Parameter p, Parameter q, string condition, boolean withIn
where c.fromSource() and ParameterAliasing::aliasing(c, p, q, condition, withIn)
select c, p.getName(), q.getName(), condition, withIn
