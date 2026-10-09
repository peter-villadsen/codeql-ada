/**
 * @name Allocation not provably deallocated
 * @description Storage allocated with `new` whose access value cannot be shown to
 *              reach a deallocation (`Free (X)`, an instance of
 *              Ada.Unchecked_Deallocation). Either the storage is never released, or
 *              it is released in a way the data-flow library does not follow: kept in
 *              a record component, an array or a variable of an enclosing subprogram,
 *              or in a container.
 * @kind problem
 * @id my-app/allocation-not-provably-deallocated
 * @problem.severity recommendation
 */

import ada
import codeql.ada.dataflow.DataFlow

/** Holds if `free` calls an instance of Ada.Unchecked_Deallocation: `Free (X)`. */
predicate isDeallocation(CallExpr free) {
  free.getName()
      .getReferencedDecl()
      .(GenericInstantiation)
      .getDesignatedGeneric()
      .hasQualifiedName("Ada.Unchecked_Deallocation")
}

module Config implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { n.asExpr() instanceof Allocator }

  // The access value handed to a deallocation.
  predicate isSink(DataFlow::Node n) {
    exists(CallExpr free | isDeallocation(free) |
      n.asExpr() = free.getSuffix().(AssocList).getChild(0).(ParamAssoc).getRExpr()
    )
  }
}

module Flow = DataFlow::Global<Config>;

from Allocator alloc, DataFlow::Node n
where
  n.asExpr() = alloc and
  not Flow::flow(n, _) and
  alloc.fromSource()
select alloc, "This storage is not provably deallocated."
