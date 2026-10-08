/**
 * Formal parameters of subprogram specs, flattened across `ParamSpec` groups. Shared by
 * `codeql.ada.Subprograms` and the data-flow library, which must agree on positions.
 */

private import codeql.ada.ast.internal.Raw

/**
 * Gets the `SubpSpec` of a callable declaration: functions and procedures, as specs,
 * bodies, expression functions, null procedures, renamings and body stubs. Entries,
 * protected entries and generic subprograms have none (D-023).
 */
Raw::SubpSpec subpSpecOf(Raw::BasicDecl d) {
  result = d.(Raw::ClassicSubpDecl).getSubpSpec()
  or
  result = d.(Raw::BaseSubpBody).getSubpSpec()
  or
  // a separate body's stub (`procedure P is separate;`), the declaration when there
  // is no other; `ada_body_part` pairs it with the subunit's body
  result = d.(Raw::SubpBodyStub).getSubpSpec()
}

/**
 * Gets the `SubpSpec` of a callable declaration as the library's `Subprogram` sees
 * it: `subpSpecOf`, and also a generic subprogram (`generic ... procedure G (...)`)
 * and its inner declaration. Data flow uses `subpSpecOf` only: it does not follow
 * calls into generics (D-023).
 */
Raw::SubpSpec callableSpecOf(Raw::BasicDecl d) {
  result = subpSpecOf(d)
  or
  result = d.(Raw::GenericSubpDecl).getSubpDecl().getSubpSpec()
  or
  result = d.(Raw::GenericSubpInternal).getSubpSpec()
}

/**
 * Gets any formal parameter's defining name, from any `ParamSpec` group, of
 * `spec` -- flattened across groups, since Ada allows one group to declare
 * several names sharing a mode and type (`A, B : in out Integer`), and
 * positional argument matching counts each name, not each group.
 */
private Raw::DefiningName anyFormalName(Raw::SubpSpec spec) {
  result = spec.getSubpParams().getParams().getChild(_).(Raw::ParamSpec).getIds().getChild(_)
}

/**
 * Gets a sort key placing `dn` -- one of `spec`'s formals, see `anyFormalName`
 * -- in formal-parameter order: group index, then id-within-group index, each
 * read off `dn`'s own position among its siblings (`getParentIndex()`) rather
 * than by inverting `getChild` (which needs its index argument already
 * bound).
 */
private int formalKey(Raw::SubpSpec spec, Raw::DefiningName dn) {
  exists(Raw::ParamSpec ps |
    dn = anyFormalName(spec) and
    dn = ps.getIds().getChild(_) and
    ps = spec.getSubpParams().getParams().getChild(_) and
    result = ps.getParentIndex() * 1000 + dn.getParentIndex()
  )
}

/**
 * Gets the 0-based flattened formal index of `dn` among `spec`'s formals (see
 * `formalKey`). `count`, not `strictcount`: the first formal has nothing
 * preceding it, an empty range, and `strictcount` -- unlike `count` -- has no
 * result at all over an empty range, which silently dropped the first formal
 * of every `SubpSpec` (confirmed empirically: only the second of two formals
 * ever showed up, see `docs/phase9.2-plan.md` Task 9.2.3).
 */
int formalIndex(Raw::SubpSpec spec, Raw::DefiningName dn) {
  dn = anyFormalName(spec) and
  result =
    count(Raw::DefiningName other |
      other = anyFormalName(spec) and formalKey(spec, other) < formalKey(spec, dn)
    )
}

/** Gets the `i`th formal (0-based, flattened across `ParamSpec` groups -- see `anyFormalName`) of `spec`. */
Raw::DefiningName formalAt(Raw::SubpSpec spec, int i) { i = formalIndex(spec, result) }
