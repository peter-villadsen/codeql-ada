/** `codeql.ada.adacontrol.Units` on the shipped query's test sources: every library unit, and whether it is unreferenced. */

import ada
import codeql.ada.adacontrol.Units

from BasicDecl d
where Units::isLibraryUnit(d) and d.fromSource()
select d, any(string s | if Units::isUnreferenced(d) then s = "unreferenced" else s = "withed")
