/**
 * @name Predefined-target dump (golden extractor regression test)
 * @description Dumps every name in the project that resolves into a predefined
 *              pseudo-source -- package Standard or a runtime unit (D-026) --
 *              with the target's kind, name and file. Regression guard on the
 *              two-pass extraction: the target must exist, be walked, and sit in
 *              a file marked by ada_predefined_file. Runtime files are printed by
 *              base name only, so the output does not depend on the GNAT install.
 * @id ada/test/print-predefined
 * @kind table
 */

import ada

from Name n, BasicDecl target, File f, string name
where
  n.(AdaNode).fromSource() and
  target = n.getReferencedDecl() and
  locations_default(target.getLocation(), f, _, _, _, _) and
  f.isPredefined() and
  name = concat(target.getAName(), ", ")
select n, target.getAPrimaryQlClass(), name,
  f.getAbsolutePath().regexpCapture(".*/([^/]*)", 1)
