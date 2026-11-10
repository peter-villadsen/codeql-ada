/**
 * @name Elaboration depends on elaboration order
 * @description When the elaboration of a library package calls a subprogram of
 *              another unit, or instantiates one of its generics, that unit's body must
 *              have been elaborated first, or `Program_Error` is raised. Without
 *              `pragma Elaborate_All` for that unit, this depends on the order the
 *              binder picks. AdaControl rule `Unsafe_Elaboration`: library packages,
 *              generic or not, whose elaboration code or task bodies, directly or
 *              through the package's own subprograms, call or instantiate units that
 *              are not language-defined and are not named by `pragma Elaborate` or
 *              `Elaborate_All`. See `codeql.ada.adacontrol.UnsafeElaboration`
 *              (`docs/adacontrol.md`).
 * @id ada/unsafe-elaboration
 * @kind problem
 * @problem.severity recommendation
 * @precision medium
 * @tags reliability adacontrol
 */

import ada
import codeql.ada.adacontrol.UnsafeElaboration

/** Gets the path of the file `n` is in. */
string filePath(AdaNode n) { n.getLocation().hasLocationInfo(result, _, _, _, _) }

from Raw::BasicDecl p, Raw::BasicDecl u, AdaNode site
where
  p.fromSource() and
  UnsafeElaboration::unsafe(p, u, site) and
  // one result per package and unit: the first site in the package's spec, else its body
  site =
    min(AdaNode s |
      UnsafeElaboration::unsafe(p, u, s)
    |
      s
      order by
        filePath(s), s.getLocation().getStartLine(),
        s.getLocation().getStartColumn()
    )
select site,
  "The elaboration of package " + p.getQualifiedName() + " uses unit " + u.getQualifiedName() +
    " here, with no pragma Elaborate_All for it."
