# codeql-ada

CodeQL language support for **Ada**: an extractor built on
[Libadalang](https://github.com/AdaCore/libadalang), a database schema, QL
libraries, and a query suite — enabling `codeql database create --language=ada`
and, from there, the same static-analysis workflow CodeQL already offers for
C++, Java, Python, and a dozen other languages.

> **Status:** pre-1.0, released as [v0.2.0](CHANGELOG.md): an extractor, a QL
> library with control flow, data flow and taint tracking, and 25 queries
> (28 on `master`), tested on a 5-project real-world corpus. The database format
> may still change between releases, so expect to rebuild databases when you
> upgrade. [docs/known-limitations.md](docs/known-limitations.md) lists what
> doesn't work yet. Bug reports, false positives and missed results are welcome as
> [issues](https://github.com/peter-villadsen/codeql-ada/issues).

If you already know CodeQL from another language, most of what follows will
be familiar; the parts specific to Ada (project discovery, name-resolution
quality, known limitations) are called out explicitly. If you're coming to
CodeQL for the first time, read on — the next section explains the moving
parts before the quickstart uses them.

## What CodeQL is, briefly

[CodeQL](https://codeql.github.com/) turns a codebase into a **database**: a
relational snapshot of the code's syntax tree, plus semantic facts like
"this reference resolves to that declaration" or "this expression has this
type". You then query that database in **QL**, a declarative query language
purpose-built for this — a query like "find every `Unchecked_Conversion`
instantiation" is a handful of lines instead of a hand-rolled AST walk.

Three pieces make this work for a new language:

- **The extractor** — a program that reads source code and populates the
  database. For Ada, this project's extractor is a Python program built on
  Libadalang (AdaCore's Ada front-end); it needs no compiler and no build,
  just your source tree and, optionally, a GNAT project (`.gpr`) file for
  best-quality name resolution (see
  [Project discovery](docs/user-guide.md#project-discovery-and-name-resolution-quality)
  in the user guide).
- **QL packs** — versioned bundles of QL code, the same way a language has
  package registries for libraries. This project ships two: `ada-all` (the
  library — reusable classes like `Name` and `Expr` that queries build on)
  and `ada-queries` (ready-to-run queries built on that library).
- **The CodeQL CLI** — GitHub's command-line tool that drives extraction and
  query evaluation. It is proprietary software with its own license, which allows
  analyzing open-source code without charge and requires a GitHub license for other
  code (see [License](#license)). It isn't bundled here — you install it yourself,
  once, and point it at whichever language's extractor and packs you need.

## Requirements

| Requirement | Details |
|---|---|
| OS | Linux x86_64 with glibc 2.38 or newer (Ubuntu 24.04, Debian 13); Windows via WSL |
| Python | ≥ 3.11, already on `PATH` (system Python is fine — no install needed, see below) |
| CodeQL CLI | 2.25.6 tested; [download separately](https://github.com/github/codeql-cli-binaries) under GitHub's own terms |

Native macOS and Windows are not supported yet (D-010); WSL is the documented
path for Windows users, and works identically to native Linux.

## Installing

Download the extractor from the latest release. No Libadalang build is
needed, because the tarball bundles the Libadalang runtime it needs (D-010):

```sh
curl -sSLO https://github.com/peter-villadsen/codeql-ada/releases/latest/download/codeql-extractor-ada-linux64.tar.gz
tar xzf codeql-extractor-ada-linux64.tar.gz
```

To build the tarball yourself instead, in WSL/Debian 13 (see
[CONTRIBUTING.md](CONTRIBUTING.md) for the dev environment setup):

```sh
scripts/build-libadalang.sh          # ~45 min the first time; builds Libadalang from source
scripts/create-extractor-pack.sh     # bundles it into codeql-extractor-ada-linux64.tar.gz
```

Either way, extraction leaves an `ada/` directory — that's the extractor
pack. Its parent directory is what you pass to `--search-path` below.

## Quickstart

```sh
# 1. Create a database from your Ada project (a GNAT .gpr project or a bare
#    source tree both work -- see the user guide for how project discovery
#    picks between them).
codeql database create mydb --language=ada --build-mode=none \
  --search-path=<dir containing ada/> --source-root=<path to your Ada project>

# 2. Run the query suite and get results as SARIF (the same format GitHub
#    code scanning and most editors/CI integrations consume).
codeql database analyze mydb peter-villadsen/ada-queries \
  --format=sarif-latest --output=results.sarif
```

`--build-mode=none` tells CodeQL there's nothing to compile — Libadalang
resolves Ada semantics from your `.gpr` file (or, absent one, by parsing
every `.ads`/`.adb` it finds) without invoking GNAT at all.

To run this on every push and get the findings into GitHub code scanning, see
[docs/ci-integration.md](docs/ci-integration.md) — note that you cannot simply
add `ada` to the CodeQL Action's language list, and the guide explains what to
do instead.

Your own queries read like CodeQL queries for other languages. The parameters of
a subprogram:

```ql
import ada

from Subprogram s, Parameter p
where s.hasQualifiedName("My_App.Logs.Open_Log") and p = s.getAParameter()
select p, p.getName(), p.getMode(), p.getType()
```

and data flow and taint tracking follow values across subprograms, from a source
such as `Ada.Environment_Variables.Value` to a sink such as
`Ada.Directories.Delete_File`. [docs/query-writing.md](docs/query-writing.md) has
complete, tested examples, including one that lists allocations not provably
deallocated.

**[docs/user-guide.md](docs/user-guide.md) is the complete manual**: setting up
(including the CodeQL CLI), analyzing a project, writing ad-hoc queries with worked
examples (recursion, statement counts, cyclomatic complexity, SQL injection), running
in GitHub Actions and Azure DevOps, and troubleshooting. Beyond it,
[docs/query-writing.md](docs/query-writing.md) covers the QL library in depth and
[docs/ast-reference.md](docs/ast-reference.md) the tree each Ada construct becomes.

## Why

CodeQL has no Ada support, official or community, despite Ada being the
implementation language of choice for the kind of high-assurance software
(avionics, defense, rail) where static analysis matters most. Libadalang
parses 100% of Ada 2022 and provides name resolution from GNAT project files
without invoking a compiler, which is what makes a build-less CodeQL
extractor feasible in the first place — see [DECISIONS.md](DECISIONS.md) for
the full rationale behind each design choice, and [BURNDOWN.md](BURNDOWN.md)
for the project's history and current state.

## License

[MIT](LICENSE) for this project's own code (extractor, dbscheme, QL packs,
queries). The CodeQL CLI itself is proprietary and licensed separately by
GitHub; you obtain it under the
[GitHub CodeQL Terms](https://github.com/github/codeql-cli-binaries/blob/main/LICENSE.md).

**Which code you may analyze is set by the CodeQL CLI's license, not by this
project's.** Under the
[GitHub CodeQL Terms](https://github.com/github/codeql-cli-binaries/blob/main/LICENSE.md),
the CLI may be used without charge to analyze open-source codebases (released under an
OSI-approved license), for academic research, and to demonstrate CodeQL. Analyzing any
other codebase, including your organization's proprietary code and including in CI,
requires a license from GitHub (GitHub Advanced Security / GitHub Code Security). This
applies to every CodeQL language, Ada included. The terms are GitHub's; read them, and
ask GitHub, rather than relying on this summary.
Libadalang is Apache-2.0. The release tarball bundles Libadalang's runtime
and its own dependencies under their respective licenses (several are GPLv3
with the GCC Runtime Library Exception, which is what permits bundling them
alongside this project's MIT code) — see
[extractors/ada/THIRD_PARTY_NOTICES.md](extractors/ada/THIRD_PARTY_NOTICES.md)
for the full breakdown.
