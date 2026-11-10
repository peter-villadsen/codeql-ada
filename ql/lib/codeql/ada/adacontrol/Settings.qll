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
