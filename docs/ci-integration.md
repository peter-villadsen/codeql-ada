# Running the Ada pack in CI

How to analyze an Ada codebase on every push and get the findings in front of
developers. This guide covers **[GitHub Actions with code scanning](#the-workflow)** and
**[Azure DevOps](#azure-devops)**, including [air-gapped agents](#air-gapped-agents). The
setup is identical on both up to the point where `results.sarif` exists; only publishing
differs.

If you have never run this locally, do that first: the [README](../README.md#quickstart)
quickstart is the same three commands this workflow automates, and debugging them on your
own machine is much faster than debugging them in a runner.

---

## The one thing that surprises everyone

**You cannot write `languages: ada` in `github/codeql-action/init`.**

The CodeQL Action only knows the languages GitHub ships an extractor for, and Ada is not
one of them. Adding it to the language matrix fails with an unrecognised-language error,
and no amount of configuration changes that — it is not a permissions or setup problem.

Third-party extractors integrate a different way, which this guide follows throughout:

1. install the CodeQL **CLI** yourself,
2. install the Ada **extractor** yourself,
3. run `database create` and `database analyze` as ordinary shell steps,
4. hand the resulting SARIF to `github/codeql-action/upload-sarif`.

Only step 4 uses the CodeQL Action, and `upload-sarif` accepts SARIF from any tool. The
result is indistinguishable from a first-party analysis once it lands: the same Security →
Code scanning list, the same PR annotations, the same dismissal workflow.

---

## Prerequisites

| Requirement | Value | Why |
|---|---|---|
| Runner OS | Linux x86-64 (`ubuntu-24.04`) | The extractor ships as `codeql-extractor-ada-linux64.tar.gz`. There is no Windows or macOS build, and no arm64 build. |
| Python on the runner | ≥ 3.11 | The extractor is Python; the Libadalang runtime it needs is bundled in the tarball, so nothing else has to be installed. GitHub's Ubuntu images already satisfy this. |
| CodeQL CLI | **exactly 2.25.6** | Pinned by decision D-012. The dbscheme and the shared QL packs are matched to this version; a newer CLI is not guaranteed to load the database. |
| Code scanning | public repo, or GitHub Advanced Security on a private one | `upload-sarif` needs code scanning enabled. Without it the analysis still runs — see [Without code scanning](#without-code-scanning). |
| Repository permission | `security-events: write` | Required to upload results. Set it in the workflow, as below. |

> **Availability note.** At the time of writing this repository has **no tagged release
> and no published query pack**, so the download URLs below have nothing to serve yet.
> Cutting a release produces both (the tag-driven `release.yml` builds the extractor
> tarball and publishes `ada-all`/`ada-queries` to GHCR). Until then, use the
> [vendored-extractor path](#vendoring-the-extractor) instead, which works today and is
> also what air-gapped environments will want.

---

## The workflow

Save as `.github/workflows/codeql-ada.yml` in the repository you want analyzed.

```yaml
name: CodeQL (Ada)

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    # A weekly run catches findings introduced by query-pack updates, not just by
    # your own commits.
    - cron: '30 2 * * 1'

permissions:
  contents: read
  security-events: write   # required by upload-sarif

jobs:
  analyze:
    name: Analyze Ada
    # Linux x86-64 only -- see Prerequisites.
    runs-on: ubuntu-24.04
    timeout-minutes: 60

    env:
      # Pin both. See "Reproducibility" below for why this matters more than usual.
      CODEQL_CLI_VERSION: 2.25.6
      ADA_EXTRACTOR_VERSION: v0.1.0
      ADA_QUERY_PACK: peter-villadsen/ada-queries

    steps:
      - uses: actions/checkout@v4

      - name: Cache CodeQL CLI and Ada extractor
        id: tools-cache
        uses: actions/cache@v4
        with:
          path: |
            ~/codeql-cli
            ~/ada-extractor
          key: codeql-${{ env.CODEQL_CLI_VERSION }}-ada-${{ env.ADA_EXTRACTOR_VERSION }}

      - name: Install the CodeQL CLI
        if: steps.tools-cache.outputs.cache-hit != 'true'
        run: |
          set -euo pipefail
          curl -sSL -o /tmp/codeql.zip \
            "https://github.com/github/codeql-cli-binaries/releases/download/v${CODEQL_CLI_VERSION}/codeql-linux64.zip"
          mkdir -p ~/codeql-cli
          unzip -q /tmp/codeql.zip -d ~/codeql-cli

      - name: Install the Ada extractor
        if: steps.tools-cache.outputs.cache-hit != 'true'
        run: |
          set -euo pipefail
          curl -sSL -o /tmp/ada-extractor.tar.gz \
            "https://github.com/peter-villadsen/codeql-ada/releases/download/${ADA_EXTRACTOR_VERSION}/codeql-extractor-ada-linux64.tar.gz"
          mkdir -p ~/ada-extractor
          tar -xzf /tmp/ada-extractor.tar.gz -C ~/ada-extractor

      - name: Add CodeQL to PATH
        run: echo "$HOME/codeql-cli/codeql" >> "$GITHUB_PATH"

      # A lock file pins a version; it does not put the pack on disk. Download it
      # explicitly rather than relying on `analyze` to fetch it.
      - name: Download the Ada query pack
        run: codeql pack download "$ADA_QUERY_PACK"

      - name: Create the database
        run: |
          set -euo pipefail
          codeql database create ada-db \
            --language=ada \
            --build-mode=none \
            --search-path="$HOME/ada-extractor" \
            --source-root=.

      - name: Analyze
        run: |
          set -euo pipefail
          codeql database analyze ada-db "$ADA_QUERY_PACK" \
            --format=sarif-latest \
            --output=ada-results.sarif

      - name: Upload results to code scanning
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: ada-results.sarif
          # Keeps Ada alerts in their own set, so a repo that also analyzes C# or
          # Python does not have one language's run retire the other's alerts.
          category: ada

      # Useful while you are still tuning: the raw SARIF, downloadable from the run.
      - name: Upload SARIF as an artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: ada-results-sarif
          path: ada-results.sarif
```

---

## What each part is doing

### `--build-mode=none`

Not a shortcut, and not "skip the build". Most extractors watch a real compiler run to
learn what to analyze. This one never invokes GNAT: Libadalang resolves Ada semantics
directly from your `.gpr` project file. There is nothing to build and no `--command` to
pass. See the [user guide](user-guide.md#creating-a-database) for the full explanation.

The practical consequence for CI is a good one — **you do not need a working GNAT
toolchain on the runner**, only the extractor tarball.

### `--search-path="$HOME/ada-extractor"`

The tarball unpacks to a directory containing `ada/`. `--search-path` wants the
**parent** of that `ada/` directory, not the `ada/` directory itself. Getting this
wrong produces `Could not find extractor for language ada`, which reads like a missing
download but is almost always a path off by one level.

### `codeql pack download` before `analyze`

Our own CI broke on exactly this: a committed `codeql-pack.lock.yml` pins a version, but
the pack still has to be **downloaded into the local cache** before anything can compile
against it. Developer machines usually have it already, so the failure only shows up on a
clean checkout — which every CI run is. Download explicitly.

### `category: ada`

The category namespaces the alerts. Without it, if the repository also runs a first-party
CodeQL analysis, each upload looks to GitHub like a fresh complete result set for the
whole repo, and one language's run will close the other's alerts as "fixed". Set it once,
on the upload step. (There is also a `--sarif-category` flag on `analyze`; use one or the
other, not both with different values.)

---

## Reproducibility

Pin both versions, and treat them as a matched pair.

`CODEQL_CLI_VERSION` is not a floating "latest". The dbscheme this extractor emits and the
shared QL packs it depends on are matched to CLI 2.25.6 (decision D-012). Bumping the CLI
without bumping the extractor is the single most likely way to get a confusing failure —
typically "the CodeQL database is not compatible with a QL library referenced by the
query", which sounds like a query problem and is actually a version-skew problem.

`ADA_EXTRACTOR_VERSION` pins the analysis itself. Findings change when the pack changes;
pinning means a red build is caused by your commit, not by someone else's release. Bump it
deliberately, and expect the finding set to move when you do.

---

## Selecting the right project in a multi-`.gpr` repository

The extractor picks a GNAT project in three steps, each a fallback for the one before:
an explicit environment variable, then a single `.gpr` found anywhere under the source
root, then a project-less mode that parses every `.ads`/`.adb` it finds.

All three extract successfully — what changes is **name-resolution quality**, and with it
the accuracy of every query that resolves a name or a type. In a repository with more than
one `.gpr`, auto-detection cannot choose for you and silently falls back to the weakest
mode. Be explicit:

```yaml
      - name: Create the database
        env:
          CODEQL_EXTRACTOR_ADA_GPR: ${{ github.workspace }}/build/my_project.gpr
        run: |
          codeql database create ada-db --language=ada --build-mode=none \
            --search-path="$HOME/ada-extractor" --source-root=.
```

If your build has several project files for different configurations, analyze the one
whose closure covers the most source — or run the job once per `.gpr` with a distinct
`category:` for each, which keeps the alert sets separate.

---

## Performance

Extraction dominates the run; query evaluation is comparatively cheap. Measured on this
project's corpus, a 1,700-file codebase extracts in a few minutes and evaluates all 24
queries in seconds.

- **`CODEQL_EXTRACTOR_ADA_JOBS`** controls parallelism (default: CPU count). Each worker
  loads its own Libadalang context and re-parses the dependency closure it needs, so
  speedup is real but sublinear — do not expect it to scale with core count.
- **Cache the tools, not the database.** The workflow above caches the CLI and extractor
  keyed on their versions, which is a large saving. Caching the database itself is not
  worth it: it is invalidated by any source change, which is every run.
- **Do not run this on every push to every branch** for a large codebase. `pull_request`
  plus a schedule is usually the right trade.

---

## Vendoring the extractor

For air-gapped networks, or simply to avoid depending on a download at analysis time,
commit the extractor to your own repository or artifact store instead of fetching it:

1. Obtain `codeql-extractor-ada-linux64.tar.gz` once — from a release, or by building it
   with `scripts/create-extractor-pack.sh` on a machine that has Libadalang.
2. Store it wherever your organisation keeps binary dependencies (an internal artifact
   feed, an LFS-tracked path, a container image layer).
3. Replace the "Install the Ada extractor" step with an unpack of your copy.

Do the same for the query pack: `codeql pack download` needs GHCR, so on a disconnected
runner you want the pack vendored too. `codeql pack create` produces a self-contained pack
directory you can commit and point `analyze` at by path instead of by name.

This is also the foundation of the Azure DevOps guidance to come — self-hosted agents in
regulated environments generally cannot reach GHCR at all.

---

## Without code scanning

Code scanning upload needs a public repository or GitHub Advanced Security. Without
either, drop the `upload-sarif` step and keep the artifact upload; you still get a
machine-readable `results.sarif` per run. To fail the build on findings instead of just
recording them, add:

```yaml
      - name: Fail on any finding
        run: |
          count=$(jq '[.runs[].results[]] | length' ada-results.sarif)
          echo "Ada findings: $count"
          [ "$count" -eq 0 ]
```

Gate on severity or on a specific rule id rather than on the total, unless you are
starting from a clean codebase — 24 quality rules over an existing Ada project will find
things on day one.

---

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Unrecognized language: ada` in `codeql-action/init` | You are trying to use the CodeQL Action's language matrix. It cannot work — see [the top of this guide](#the-one-thing-that-surprises-everyone). |
| `Could not find extractor for language ada` | `--search-path` points *at* the `ada/` directory instead of its parent. |
| `Pack 'codeql/...' was not found in the pack download cache` | Missing `codeql pack download`. A lock file alone does not put the pack on disk. |
| `The CodeQL database is not compatible with a QL library...` | CLI/extractor version skew. Both must match the pinned pair. |
| Analysis succeeds, zero results, and you expected some | Check the extraction diagnostics. A database built in project-less mode still extracts, but resolves far fewer names — set `CODEQL_EXTRACTOR_ADA_GPR`. |
| `no-runtime` warning diagnostic; many `unused-parameter` / `unused-local` results on names that are plainly used | No GNAT runtime visible to a project-less extraction. Install `gnat` on the runner, or set `CODEQL_EXTRACTOR_ADA_RUNTIME` to its `adainclude` directory. |
| Alerts from a previous run get closed unexpectedly | Missing or inconsistent `category:` when more than one analysis uploads to the repo. |
| `Resource not accessible by integration` on upload | Missing `security-events: write` in `permissions:`. |

---

## Azure DevOps

Everything up to producing `results.sarif` is identical — same CLI, same extractor, same
two commands. Two things differ.

**There is no native code-scanning surface.** ADO has no equivalent of GitHub's Security
tab. The usual way to see SARIF in the UI is the **SARIF SAST Scans Tab** extension, which
renders any SARIF it finds in a build artifact named — exactly — `CodeAnalysisLogs`. That
artifact name is not a convention you can choose; the extension looks for that string. If
your organisation will not install marketplace extensions, publish the SARIF as an ordinary
artifact and gate the build instead (below).

**Agents are often self-hosted and frequently offline.** That is the normal case in the
regulated environments where Ada lives, and it changes the setup more than the pipeline
syntax does — see [Air-gapped agents](#air-gapped-agents).

### Microsoft-hosted agents

`azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include: [main]

pool:
  # Linux x86-64 only -- the extractor ships no other build.
  vmImage: ubuntu-24.04

variables:
  CODEQL_CLI_VERSION: 2.25.6
  ADA_EXTRACTOR_VERSION: v0.1.0
  ADA_QUERY_PACK: peter-villadsen/ada-queries
  TOOLS_DIR: $(Pipeline.Workspace)/ada-tools

steps:
  - checkout: self

  - task: Cache@2
    displayName: Cache CodeQL CLI and Ada extractor
    inputs:
      key: 'ada-tools | "$(CODEQL_CLI_VERSION)" | "$(ADA_EXTRACTOR_VERSION)"'
      path: $(TOOLS_DIR)
      cacheHitVar: TOOLS_CACHED

  - script: |
      set -euo pipefail
      mkdir -p "$(TOOLS_DIR)/cli" "$(TOOLS_DIR)/extractor"
      curl -sSL -o /tmp/codeql.zip \
        "https://github.com/github/codeql-cli-binaries/releases/download/v$(CODEQL_CLI_VERSION)/codeql-linux64.zip"
      unzip -q /tmp/codeql.zip -d "$(TOOLS_DIR)/cli"
      curl -sSL -o /tmp/ada-extractor.tar.gz \
        "https://github.com/peter-villadsen/codeql-ada/releases/download/$(ADA_EXTRACTOR_VERSION)/codeql-extractor-ada-linux64.tar.gz"
      tar -xzf /tmp/ada-extractor.tar.gz -C "$(TOOLS_DIR)/extractor"
    displayName: Install CodeQL CLI and Ada extractor
    condition: ne(variables.TOOLS_CACHED, 'true')

  - script: echo "##vso[task.prependpath]$(TOOLS_DIR)/cli/codeql"
    displayName: Add CodeQL to PATH

  - script: codeql pack download "$(ADA_QUERY_PACK)"
    displayName: Download the Ada query pack

  - script: |
      set -euo pipefail
      codeql database create "$(Agent.TempDirectory)/ada-db" \
        --language=ada --build-mode=none \
        --search-path="$(TOOLS_DIR)/extractor" \
        --source-root="$(Build.SourcesDirectory)"
    displayName: Create the database

  - script: |
      set -euo pipefail
      mkdir -p "$(Build.ArtifactStagingDirectory)/CodeAnalysisLogs"
      codeql database analyze "$(Agent.TempDirectory)/ada-db" "$(ADA_QUERY_PACK)" \
        --format=sarif-latest \
        --output="$(Build.ArtifactStagingDirectory)/CodeAnalysisLogs/ada.sarif"
    displayName: Analyze

  # The SARIF SAST Scans Tab extension reads from an artifact with this exact name.
  - task: PublishBuildArtifacts@1
    displayName: Publish SARIF
    condition: always()
    inputs:
      PathtoPublish: $(Build.ArtifactStagingDirectory)/CodeAnalysisLogs
      ArtifactName: CodeAnalysisLogs
```

### Failing the build on findings

Without a Security tab, a finding that nobody looks at may as well not exist. Gate the
build:

```yaml
  - script: |
      set -euo pipefail
      sarif="$(Build.ArtifactStagingDirectory)/CodeAnalysisLogs/ada.sarif"
      count=$(jq '[.runs[].results[]] | length' "$sarif")
      echo "Ada findings: $count"
      if [ "$count" -gt 0 ]; then
        echo "##vso[task.logissue type=warning]Ada analysis reported $count finding(s)"
        echo "##vso[task.complete result=SucceededWithIssues;]"
      fi
    displayName: Report findings
```

Start with `SucceededWithIssues`, not a hard failure. Twenty-four quality rules over an
existing Ada codebase will find things on day one, and a pipeline that goes red
immediately gets disabled rather than fixed. Tighten to `result=Failed`, or to a specific
rule id or severity, once the baseline is clean.

### Air-gapped agents

On a disconnected agent nothing can be downloaded: not the CLI, not the extractor, and
not the query pack. Everything has to be staged in advance. Three pieces, in increasing
order of surprise:

1. **The CodeQL CLI** — mirror `codeql-linux64.zip` for the pinned version to your
   internal artifact feed.
2. **The extractor tarball** — likewise, per
   [Vendoring the extractor](#vendoring-the-extractor).
3. **The QL packs, *including the shared CodeQL packs*.** This is the one people miss.
   `codeql pack download` needs GHCR, so instead you vendor the query pack **as source**
   — the `ql/` directory of this repository is small and pure text — and analyze it by
   path. But `ql/src` depends on `ql/lib`, which depends on `codeql/controlflow` and
   `codeql/util`, and *those* still have to come from somewhere. Copy them from a
   connected machine:

   ```sh
   # on a machine that has run `codeql pack install`
   cp -a ~/.codeql/packages/codeql /your/vendor/dir/
   ```

   Then point `--additional-packs` at both the vendor directory and the repository's
   `ql/` directory, colon-separated:

   ```sh
   codeql database analyze ada-db /path/to/ql/src \
     --format=sarif-latest --output=ada.sarif \
     --additional-packs=/your/vendor/dir:/path/to/ql \
     --search-path=/path/to/extractor
   ```

   Note that the query pack is named by **path** (`/path/to/ql/src`) rather than by pack
   name — naming it `peter-villadsen/ada-queries` would send the CLI looking for a
   registry.

   This path is verified: with `~/.codeql/packages` removed entirely, the command above
   resolves every dependency and produces SARIF listing all 24 rules.

If your agents can reach an internal proxy but not GHCR, the alternative is a private
CodeQL package registry, which the CLI supports through `--registries-auth-stdin` and a
`qlconfig.yml`. That is a heavier setup and out of scope here, but it exists, and it is
worth asking your platform team about before committing to vendoring.

### Notes on ADO specifics

- **Shell syntax.** `$(VAR)` is ADO macro substitution, resolved *before* the script runs;
  `$VAR` is ordinary shell. The examples deliberately use `$(...)` for pipeline variables
  and `$...` for nothing else, so there is no ambiguity.
- **`condition: always()`** on the publish step — otherwise a failed analysis leaves you
  with no SARIF to inspect, which is exactly when you want it.
- **Workspace paths.** `$(Agent.TempDirectory)` for the database, not the sources
  directory. A database written under `$(Build.SourcesDirectory)` gets picked up by the
  next extraction run as if it were source.
- **Timeouts.** ADO's default job timeout on hosted agents is 60 minutes. Extraction
  dominates; see [Performance](#performance).
