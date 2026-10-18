/**
 * Provides classes for working with static single assignment (SSA) form.
 *
 * A `SsaDefinition` is one value a local variable, parameter or loop variable
 * (`SsaSourceVariable`) holds: an explicit write (`SsaExplicitWrite`, with
 * `SsaParameterInit` for a parameter's value on entry), an uncertain write
 * (`SsaUncertainWrite`: an `out`/`in out` actual, or a call that may store into a
 * variable it shares), or a phi definition where control flow merges
 * (`SsaPhiDefinition`). `getARead()` gives the reads it reaches.
 *
 * ```ql
 * import ada
 * import codeql.ada.dataflow.Ssa
 *
 * from SsaParameterInit def
 * select def.getARead(), "Reads the value passed for " + def.getParameter().getName() + "."
 * ```
 */

private import codeql.ada.dataflow.internal.SsaImpl as SsaImpl
import SsaImpl::Ssa

/** A local variable, parameter or loop variable that SSA tracks. */
final class SsaSourceVariable = SsaImpl::SsaSourceVariable;

/** A write to a variable written in the source; see `SsaExplicitWrite.getDefinition()`. */
final class VariableWrite = SsaImpl::VariableWrite;
