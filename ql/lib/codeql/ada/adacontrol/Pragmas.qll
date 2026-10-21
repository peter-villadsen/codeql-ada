/**
 * AdaControl rule `Pragmas`: uses of given pragmas, of all pragmas, of non-standard
 * ones, and pragmas that apply to several entities (`docs/adacontrol.md`).
 */

private import codeql.ada.ast.internal.Raw

module Pragmas {
  /** Gets the name of pragma `p`, lower-cased. */
  string pragmaName(Raw::PragmaNode p) { result = p.getId().getValue().toLowerCase() }

  /**
   * Holds if `name` (lower-cased) is a language-defined pragma (Ada 2022 RM, Annex L,
   * and the obsolescent ones of Annex J).
   */
  predicate isStandard(string name) {
    name =
      [
        "admission_policy", "all_calls_remote", "assert", "assertion_policy", "asynchronous",
        "atomic", "atomic_components", "attach_handler", "conflict_check_policy", "controlled",
        "convention", "cpu", "default_storage_pool", "detect_blocking", "discard_names",
        "dispatching_domain", "elaborate", "elaborate_all", "elaborate_body", "export",
        "generate_deadlines", "import", "independent", "independent_components", "inline",
        "inspection_point", "interface", "interrupt_handler", "interrupt_priority",
        "linker_options", "list", "locking_policy", "memory_size", "no_return",
        "normalize_scalars", "optimize", "pack", "page", "partition_elaboration_policy",
        "preelaborable_initialization", "preelaborate", "priority",
        "priority_specific_dispatching", "profile", "pure", "queuing_policy",
        "relative_deadline", "remote_call_interface", "remote_types", "restrictions",
        "reviewable", "shared", "shared_passive", "storage_size", "storage_unit", "suppress",
        "system_name", "task_dispatching_policy", "unchecked_union", "unsuppress", "volatile",
        "volatile_components"
      ]
  }

  /** `nonstandard`: `p` is an implementation-defined or unrecognized pragma. */
  predicate isNonstandard(Raw::PragmaNode p) { not isStandard(pragmaName(p)) }

  /** Gets the region a declaration is directly in: its declarative part. */
  private Raw::AdaNode region(Raw::BasicDecl d) { result = d.getParent().getParent() }

  /**
   * `multiple`: an argument of `p` is an overloaded name, so the pragma applies to
   * several entities: another declaration of the same name is in the same declarative
   * part as the one it resolves to.
   */
  predicate isMultiple(Raw::PragmaNode p) {
    // these pragmas evaluate their argument: a call, not a name of the entities affected
    not pragmaName(p) =
      [
        "assert", "assert_and_cut", "assume", "check", "debug", "loop_invariant",
        "loop_variant", "precondition", "postcondition", "invariant", "contract_cases"
      ] and
    exists(Raw::Name arg, Raw::BasicDecl d, Raw::BasicDecl other |
      arg = p.getArgs().getChild(_).(Raw::PragmaArgumentAssoc).getExpr() and
      d = arg.getReferencedDecl() and
      other != d and
      region(other) = region(d) and
      other.getAName().toLowerCase() = d.getAName().toLowerCase() and
      not ada_body_part(d, other) and
      not ada_body_part(other, d)
    )
  }
}
