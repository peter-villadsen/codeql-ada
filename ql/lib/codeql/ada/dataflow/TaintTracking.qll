/**
 * Global taint tracking for Ada: the entry point for queries (see
 * `docs/dataflow-design.md`). `TaintTracking::Global<Config>` takes a
 * `DataFlow::ConfigSig` and follows, besides value-preserving flow, the derived-value
 * steps listed in `internal/TaintTrackingImpl.qll`.
 */

private import codeql.ada.dataflow.internal.TaintTrackingImpl as Impl

module TaintTracking {
  import Impl::AdaTaintTracking
}
