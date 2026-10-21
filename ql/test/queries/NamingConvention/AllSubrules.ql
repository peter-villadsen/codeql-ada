/**
 * `codeql.ada.adacontrol.NamingConvention` on the shipped query's test sources: each
 * name's kind and location, and a convention with a positive and a negative pattern.
 */

import ada
import codeql.ada.adacontrol.NamingConvention

predicate rule(string kind, string pattern, boolean positive, boolean caseSensitive) {
  kind = "type" and pattern = "^[A-Z]" and positive = true and caseSensitive = true
  or
  kind = "access_type" and pattern = "_Ptr$" and positive = true and caseSensitive = false
  or
  kind = "variable" and pattern = "^Bad" and positive = false and caseSensitive = false
}

module C = NamingConvention::Convention<rule/4>;

from DefiningName dn, string what
where
  dn.fromSource() and
  (
    what = NamingConvention::kind(dn) + " " + NamingConvention::location(dn)
    or
    exists(string k, string p | C::violates(dn, k, p) | what = "violates " + k + ": " + p)
  )
select dn, what
