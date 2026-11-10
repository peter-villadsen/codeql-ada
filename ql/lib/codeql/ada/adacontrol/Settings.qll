/**
 * Settings of the AdaControl-parity queries that name entities, set through data
 * extensions (`ext/query-settings.model.yml`; `docs/user-guide.md`, "Configuring
 * queries"). Each has no rows by default.
 */

/**
 * Holds if the procedure with qualified name `qualifiedName` (`Pack.Init`, case not
 * significant) is an initialization procedure for `ada/duplicate-initialization-calls`,
 * AdaControl's `<entity>` of `Duplicate_Initialization_Calls`. With no rows, the query
 * checks the procedures named `Init` or `Initialize`.
 */
extensible predicate initializationProcedure(string qualifiedName);

/**
 * Holds if parameter `parameter` of the subprogram with qualified name `subprogram`
 * (`Pack.Register`, `CB`; case not significant) registers a call-back, for
 * `ada/exception-propagation`: AdaControl's `parameter` subrule of
 * `Exception_Propagation`. A subprogram that can propagate exceptions, passed to it as
 * `'Access` or `'Address`, is reported. With no rows, nothing is.
 */
extensible predicate callbackParameter(string subprogram, string parameter);

/**
 * Holds if `limit` is the largest call depth `ada/max-call-depth` allows, AdaControl's
 * `<allowed depth>` of `Max_Call_Depth`. With several rows, the smallest applies; with
 * none, the limit is 15.
 */
extensible predicate maxCallDepth(int limit);

/**
 * Holds if `entity` is a subprogram (by qualified name, `Pack.Init`; case not
 * significant), or `new` for allocators, that `ada/not-elaboration-calls` allows only
 * while library packages are elaborated: AdaControl's `<entity>` and `new` of
 * `Not_Elaboration_Calls`. With no rows, nothing is reported.
 */
extensible predicate notElaborationCall(string entity);

/**
 * Holds if the subprogram with qualified name `qualifiedName` (case not significant)
 * is potentially blocking, for `ada/potentially-blocking-operations`, in addition to
 * the subprograms of the language-defined input-output packages, which always are.
 */
extensible predicate blockingSubprogram(string qualifiedName);

/**
 * Holds if the function with qualified name `function` (case not significant) has
 * side effects, for `ada/side-effect-parameters`: AdaControl's entities of
 * `Side_Effect_Parameters`. Functions of one `group` (any label) interfere with each
 * other, as the functions given in one use of the AdaControl rule do. With no rows,
 * nothing is reported.
 */
extensible predicate sideEffectFunction(string function, string group);

/**
 * Holds if `ada/type-usage` reports the uses `usage` -- `index`, or an attribute such
 * as `'Image` -- of the types `type`: a category (`()`, `range`, `mod`, `access`, ...)
 * or a qualified type name (case not significant), restricted by `aspect`: empty, or
 * one of `representation`, `pack`, `size`, `component_size`, optionally preceded by
 * `not`. AdaControl's parameters of `Type_Usage`. With no rows, nothing is reported.
 */
extensible predicate typeUsage(string usage, string type, string aspect);

/**
 * Holds if the procedures with qualified names `opening` and `closing` (case not
 * significant) must be called in pairs, for `ada/unsafe-paired-calls`: AdaControl's
 * parameters of `Unsafe_Paired_Calls`. With a `lockType` (a qualified type name; empty
 * for none), the calls are paired by the actual they pass for a parameter of that
 * type. With no rows, nothing is reported.
 */
extensible predicate pairedCalls(string opening, string closing, string lockType);

/**
 * Holds if `ada/usage` reports the entities of class `entityClass` (`variable`,
 * `object`, `constant`, `in_parameter`, `out_parameter`, `in_out_parameter`, `type`,
 * `procedure`, `function`, `exception`, `task`, `protected`, `generic` or `all`) that
 * satisfy every condition of `conditions`: a comma-separated list of usage keywords
 * (`read`, `written`, `initialized`, `used`, `called`, `accessed`, `raised`,
 * `handled`, `aborted`, `instantiated`) and places (`from_visible`, `from_private`,
 * `from_spec`), each optionally preceded by `not`; empty for every entity of the
 * class. AdaControl's parameters of `Usage`. With no rows, nothing is reported.
 */
extensible predicate usage(string entityClass, string conditions);

/**
 * Holds if `ada/style` checks subrule `subrule` of AdaControl's `Style` with
 * `parameter`: the casing (`uppercase`, `lowercase`, `titlecase`; `original` for
 * identifiers) of `casing_identifier`, `casing_attribute`, `casing_pragma`,
 * `casing_aspect`, `casing_number` and `casing_exponent`, several rows accepting any
 * of them; an allowed value of `exposed_literal`; the block size of `numeric_literal`;
 * the maximum lines of a construct without closing name for `no_closing_name`;
 * `flexible` for `multiple_elements`; empty for `default_in`, `parameter_order`,
 * `formal_parameter_order` and `renamed_entity`. With no rows, the query checks its
 * default subrules (`docs/adacontrol.md`).
 */
extensible predicate styleCheck(string subrule, string parameter);
