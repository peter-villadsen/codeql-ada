/**
 * @name Use of Unchecked_Conversion
 * @description Instantiations of Ada.Unchecked_Conversion reinterpret raw bits
 *              between types, bypassing type safety; each use deserves review.
 * @id ada/unchecked-conversion
 * @kind problem
 * @problem.severity warning
 * @tags security correctness
 */

import ada

// Matched semantically (D-026): the designated generic, resolved through generic
// renamings, is `Ada.Unchecked_Conversion` or its Ada 83 library-level twin
// `Unchecked_Conversion` (a separate generic in GNAT, not a renaming). Only if the
// generic does not resolve -- no GNAT runtime at extraction -- is the name's text used.
from GenericInstantiation gi
where
  gi instanceof GenericSubpInstantiation and
  (
    gi.getDesignatedGeneric()
        
        .hasQualifiedName(["Ada.Unchecked_Conversion", "Unchecked_Conversion"])
    or
    not exists(gi.getDesignatedGeneric()) and
    gi.(GenericSubpInstantiation)
        .getGenericSubpName()
        .(Name)
        .getText()
        .toLowerCase()
        .matches("%unchecked_conversion")
  ) and
  gi.fromSource()
select gi, "Instantiation of Unchecked_Conversion bypasses type safety."
