# Cutting a release

A release produces three artifacts that consumers need and that nothing else
provides:

1. **`codeql-extractor-ada-linux64.tar.gz`**, attached to a GitHub Release — the
   self-contained extractor, bundling the Libadalang runtime so a target machine needs
   only a system Python ≥ 3.11.
2. **`peter-villadsen/ada-all` and `peter-villadsen/ada-queries` on GHCR** — the QL
   library and query packs, so `codeql pack download` works.
3. **`ghcr.io/peter-villadsen/codeql-ada:<version>`** (and `:latest`) — the container
   image Windows users create databases with (D-037). `release.yml`'s `image` job calls
   `image.yml`, which builds `container/Dockerfile` from the tarball attached to the
   Release, extracts and analyzes `tests/hello` in it offline, and pushes.

Until a release exists, [ci-integration.md](ci-integration.md) cannot be followed as
written: its download URLs have nothing to serve.

Everything is driven by pushing a `v*` tag. `workflow_dispatch` runs the same workflow as
a dry run, building and uploading the tarball as a workflow artifact but creating no
Release and publishing no packs — use it to validate changes to `release.yml` itself
without burning a version number.

---

## The version rule

`release.yml` gates on this before doing any work, and the build fails fast if it does not
hold:

```
extractors/ada/codeql-extractor.yml : version
ql/lib/qlpack.yml                   : version   ← all three must be equal
ql/src/qlpack.yml                   : version
```

and, when triggered by a tag, all three must equal the tag with its leading `v` stripped:
tag `v0.1.0` requires `version: 0.1.0`.

`ql/test` and `ql/debug` are not gated (neither is published), but keep them in step
anyway — a reader should not have to know which manifests are load-bearing.

While the database format is pre-1.0, releases stay on `0.x`. The dbscheme is not
stable across `0.x` versions: a database built by one release is not guaranteed to be
readable by the next, which is why [ci-integration.md](ci-integration.md) tells consumers
to pin.

---

## Before you tag

Work through this locally. Every command below has been run and is known to work; none of
it needs network access beyond what you already have.

**1. CI is green on `master`.** The release workflow reruns the test suite anyway, but
finding out here costs 12 minutes instead of a wasted tag.

**2. Versions bumped and consistent.**

```sh
grep -H '^version:' extractors/ada/codeql-extractor.yml ql/*/qlpack.yml
```

**3. The extractor tarball builds.** Needs a Libadalang prefix built by
`scripts/build-libadalang.sh` (`ADA_LAL_PREFIX`, default `$HOME/adacore`). Run it outside
the repo — it writes `extractor-pack/` and the tarball into the current directory:

```sh
mkdir -p ~/relcheck && cd ~/relcheck
ADA_LAL_PREFIX=$HOME/adacore bash /path/to/repo/scripts/create-extractor-pack.sh
```

**4. The tarball is genuinely self-contained.** This is the claim that matters most, and
the one most easily broken by an innocuous change to the build script: a machine with no
Libadalang must be able to use it. Clearing `PYTHONPATH` and `LD_LIBRARY_PATH` is what
makes this a real test rather than a re-run of your own working setup.

```sh
cd ~/relcheck && mkdir -p extracted
tar -xzf codeql-extractor-ada-linux64.tar.gz -C extracted

PYTHONPATH= LD_LIBRARY_PATH= \
  codeql database create ~/relcheck/testdb --language=ada --build-mode=none \
    --search-path=~/relcheck/extracted --source-root=<any Ada project>

PYTHONPATH= LD_LIBRARY_PATH= \
  codeql database analyze ~/relcheck/testdb <repo>/ql/src \
    --format=sarif-latest --output=~/relcheck/r.sarif \
    --additional-packs=<repo>/ql --search-path=~/relcheck/extracted
```

Expect a database, then valid SARIF listing all shipped rules. If step 4 fails while your
normal workflow succeeds, the tarball is missing a bundled library and the release would
ship broken.

**5. `BURNDOWN.md` reflects reality** — a release is the natural point for the burndown to
stop lying.

---

## Tagging

```sh
git tag -a v0.1.0 -m "v0.1.0"
git push origin v0.1.0
```

That push is the only irreversible step, and it is outward-facing: it creates a public
Release and publishes packs to GHCR under your account. Package versions on GHCR **cannot
be overwritten** — a botched `0.1.0` is spent, and you go to `0.1.1`. This is why the
checklist above is worth the ten minutes.

Budget ~50 minutes for the run if the Libadalang cache is cold, ~15 if warm, plus
about 10 for the image.

---

## After

- **Update the pinned example** in [ci-integration.md](ci-integration.md): its
  `ADA_EXTRACTOR_VERSION` should name the release you just cut.
- **Verify a consumer path actually works**, from a machine that has never built this
  project:
  ```sh
  codeql pack download peter-villadsen/ada-queries
  ```
  If that fails, the packs did not publish, even though the Release looks fine — the
  publish step runs after the Release is created, so a green Release is not evidence that
  the packs landed.
- **Check the image**: `docker run --rm ghcr.io/peter-villadsen/codeql-ada:<version>`
  prints the CLI version. The first time a package is published, GHCR makes it private;
  make `codeql-ada` public under the account's Packages settings, as the QL packs are.
- **Announce what changed for analysis results**, not just what changed in the code. A
  consumer who pinned a version cares primarily about whether their finding count is about
  to move.

---

## If the release fails partway

The steps are ordered tarball → Release → packs → image, and they are not
transactional.

| Failed at | State | What to do |
|---|---|---|
| Version gate | Nothing published | Fix the manifests, delete the tag locally and remotely, re-tag. |
| Test suite | Nothing published | Fix, delete and re-tag. The tag is cheap until the Release exists. |
| Tarball build | Nothing published | Usually a missing shared library in the closure; the script fails loudly with the unresolved dependency. |
| Create Release | Release may exist without the tarball | Delete the Release in the UI, then re-run. |
| Publish packs | Release exists, packs missing or partial | **Do not delete the Release.** `ada-all` may have published while `ada-queries` did not. Bump to the next patch version and re-tag — GHCR will not let you republish the same version. |
| Image | Release and packs exist, image missing | Fix the cause, then run the *Container image* workflow by hand (`gh workflow run image.yml -f tag=v<version>`). An image tag *can* be overwritten, so no new version is needed. |

Deleting a tag:

```sh
git tag -d v0.1.0
git push origin :refs/tags/v0.1.0
```
