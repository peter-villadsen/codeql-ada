/**
 * @name Exception handler swallows all exceptions
 * @description A `when others => null;` handler silently discards every
 *              exception, hiding failures from callers and operators.
 * @id ada/exception-swallowing
 * @kind problem
 * @problem.severity warning
 * @tags reliability correctness
 */

import ada

from Raw::ExceptionHandler h
where
  h.getHandledExceptions().getChild(_) instanceof Raw::OthersDesignator and
  forex(Raw::AdaNode s | s = h.getStmts().getChild(_) | s instanceof Raw::NullStmt)
select h, "Exception handler swallows all exceptions."
