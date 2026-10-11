/**
 * @name Statements per subprogram
 * @description The number of statements in each subprogram's body, not counting
 *              those of subprograms nested in it.
 * @kind table
 * @id my-app/statement-count
 */

import ada

from Subprogram s, int statements
where
  s.fromSource() and
  statements = count(Stmt st | st.getEnclosingSubprogram() = s)
select s, statements order by statements desc
