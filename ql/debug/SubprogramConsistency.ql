/**
 * @name Subprogram consistency
 * @description Every declaration of a function or procedure (spec, body, stub,
 *              expression function, null procedure, renaming) belongs to exactly one
 *              `Subprogram`. Lists the ones that belong to none or to several. Empty
 *              on a healthy database. The body of a generic subprogram belongs to
 *              none, by design in v1 (`docs/phase12-plan.md`), and is left out.
 *              Known exception: in a source tree with duplicate unit names (gpr2's
 *              testsuite), one subunit body can be paired with several stubs and
 *              then belongs to each of their subprograms (4 rows on gpr2).
 * @id ada/debug/subprogram-consistency
 * @kind table
 */

import ada
private import codeql.ada.internal.Formals

from Raw::BasicDecl d, int n
where
  exists(subpSpecOf(d)) and
  d.fromSource() and
  n = count(Subprogram s | s.getADeclaration() = d) and
  n != 1 and
  not ada_body_part(any(Raw::GenericSubpDecl g), d)
select d, d.getAPrimaryQlClass(), n, d.getLocation().toString()
