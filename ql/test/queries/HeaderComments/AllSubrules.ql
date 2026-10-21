/**
 * Every subrule of `codeql.ada.adacontrol.HeaderComments`, for the shipped query's test
 * sources: `minimum` (the header's length) and `model`.
 */

import ada
import codeql.ada.adacontrol.HeaderComments

string model(int i) {
  i = 1 and result = "^--$"
  or
  i = 2 and result = "^--  [A-Z][a-z]+: "
  or
  i = 3 and result = "Author: .+$"
}

module M = HeaderComments::Model<model/1>;

from CompilationUnit cu, string what
where
  cu.fromSource() and
  (
    what = "header lines " + HeaderComments::headerLineCount(cu)
    or
    what = "model mismatch at line " + M::firstMismatch(cu)
  )
select cu, what
