/**
 * @name Use of Unchecked_Deallocation
 * @description Instantiations of Ada.Unchecked_Deallocation free heap memory without
 *              compiler-checked lifetime tracking, risking dangling pointers and
 *              double-free if a freed access value is used or deallocated again.
 * @id ada/unchecked-deallocation
 * @kind problem
 * @problem.severity warning
 * @tags security correctness
 */

import ada

// Matched semantically (D-026): the designated generic, resolved through generic
// renamings, is `Ada.Unchecked_Deallocation` or its Ada 83 library-level twin
// `Unchecked_Deallocation`. Only if the generic does not resolve -- no GNAT runtime at
// extraction -- is the name's text used.
from GenericInstantiation gi
where
  gi instanceof GenericSubpInstantiation and
  (
    gi.getDesignatedGeneric()
        
        .hasQualifiedName(["Ada.Unchecked_Deallocation", "Unchecked_Deallocation"])
    or
    not exists(gi.getDesignatedGeneric()) and
    gi.(GenericSubpInstantiation)
        .getGenericSubpName()
        .(Name)
        .getText()
        .toLowerCase()
        .matches("%unchecked_deallocation")
  ) and
  gi.fromSource()
select gi, "Instantiation of Unchecked_Deallocation risks dangling pointers or double-free."
