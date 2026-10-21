/**
 * Every subrule of `codeql.ada.adacontrol.Comments`, for the shipped query's test
 * sources: `pattern`, `position`, `terminating` (with and without `begin`),
 * `unnamed_begin` under each condition, `unnamed_end_record` with 0 and 10 lines.
 */

import ada
import codeql.ada.adacontrol.Comments

from string where_, string what
where
  exists(Comment c | c.fromSource() and where_ = c.getLocation().getStartLine().toString() |
    Comments::matchesPattern(c, "tbsl|^p$") and what = "pattern"
    or
    Comments::column(c) != 4 and what = "position " + Comments::column(c)
    or
    exists(boolean allowBegin |
      Comments::isTerminating(c, allowBegin) and what = "terminating, begin allowed: " + allowBegin
    )
  )
  or
  exists(BodyNode b, string condition, int minLines |
    b.fromSource() and
    where_ = b.getLocation().getStartLine().toString() and
    condition = ["always", "declaration", "program_unit"] and
    minLines = [1, 3] and
    Comments::isUnnamedBegin(b, condition, minLines) and
    what =
      "unnamed_begin " + condition + " min " + minLines + " " + Comments::unitKind(b) + " " +
        Comments::unitName(b)
  )
  or
  exists(TypeDecl t, int maxLines |
    t.fromSource() and
    where_ = t.getLocation().getStartLine().toString() and
    maxLines = [0, 10] and
    Comments::isUnnamedEndRecord(t, maxLines) and
    what = "unnamed_end_record " + maxLines + " " + t.getName().getName().getText()
  )
select where_.toInt() as line, what order by line, what
