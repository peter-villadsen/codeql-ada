/** `MaxSize::lines` of every element of the shipped query's test sources, by kind. */

import ada
import codeql.ada.adacontrol.MaxSize

from AdaNode n, string kind
where MaxSize::isElement(n, kind) and n.fromSource()
select n, kind, MaxSize::lines(n)
