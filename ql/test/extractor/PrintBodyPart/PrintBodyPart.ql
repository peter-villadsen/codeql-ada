/**
 * @name Body-part dump (golden extractor regression test)
 * @description Dumps ada_body_part rows: each declaration paired with the
 *              completion Libadalang's p_body_part resolved it to (D-021).
 *              Regression guard on the call-graph relation the whole of
 *              Phase 9 is built on -- in particular that overloaded
 *              declarations each resolve to their own body, which name-text
 *              pairing cannot do.
 * @id ada/test/print-body-part
 * @kind table
 */

import ada

from BasicDecl decl
where exists(decl.getCompletion())
select decl, decl.getAPrimaryQlClass(), decl.getAName(), decl.getCompletion(),
  decl.getCompletion().getAPrimaryQlClass()
