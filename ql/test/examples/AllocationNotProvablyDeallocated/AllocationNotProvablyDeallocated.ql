/**
 * @name Allocation not provably deallocated
 * @description Storage allocated with `new` whose access value cannot be shown to
 *              reach a deallocation (`Free (X)`, an instance of
 *              Ada.Unchecked_Deallocation). Either the storage is never released, or
 *              it is released in a way the data-flow library does not follow
 *              (docs/known-limitations.md).
 * @kind problem
 * @id my-app/allocation-not-provably-deallocated
 * @problem.severity recommendation
 */

import ada
import codeql.ada.dataflow.DataFlow

module Config implements DataFlow::ConfigSig {
  predicate isSource(DataFlow::Node n) { n.asExpr() instanceof Allocator }

  // The access value handed to a deallocation: a call to an instance of
  // Ada.Unchecked_Deallocation targets the generic.
  predicate isSink(DataFlow::Node n) {
    exists(Call free |
      free.getTarget().hasQualifiedName("Ada.Unchecked_Deallocation") and
      n.asExpr() = free.getArgument(0)
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
