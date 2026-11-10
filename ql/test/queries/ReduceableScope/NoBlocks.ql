import ada
import codeql.ada.adacontrol.ReduceableScope

// `no_blocks`: block statements are not targets
from AdaNode e, AdaNode s
where ReduceableScope::innerScope(e, s, false)
select e, s
