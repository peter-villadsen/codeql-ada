# CodeQL for Ada: user guide

This is the manual for codeql-ada: what it is, how to install it, how to analyze a
project, how to write your own queries, how to run the analysis in a CI/CD pipeline,
and what to do when something goes wrong. It assumes you know Ada. It does not assume
you know CodeQL.

1. [Introduction](#introduction)
2. [Setting up](#setting-up)
3. [Analyzing a project](#analyzing-a-project)
4. [Ad-hoc queries](#ad-hoc-queries)
5. [Running in CI/CD pipelines](#running-in-cicd-pipelines)
6. [Known limitations](#known-limitations)
7. [Troubleshooting](#troubleshooting)

Two other documents go deeper than this one: [query-writing.md](query-writing.md) on
the QL library, with more worked examples, and [ast-reference.md](ast-reference.md) on
the tree each Ada construct becomes. [ci-integration.md](ci-integration.md) has CI
details this guide leaves out, such as air-gapped agents.

---

## Introduction

### What CodeQL is

[CodeQL](https://codeql.github.com/) turns a codebase into a **database**: a relational
snapshot of the code's syntax tree, plus semantic facts such as "this name refers to
that declaration" or "this expression has this type". You then ask questions of the
database in **QL**, a declarative query language made for the purpose. "Find every
instantiation of `Unchecked_Conversion`" is a handful of lines of QL, not a hand-written
walk over a syntax tree.

Three pieces make this work for a language:

- **The extractor** reads source code and fills in the database. For Ada, this project's
  extractor is a Python program built on [Libadalang](https://github.com/AdaCore/libadalang),
  AdaCore's Ada front end. It needs no compiler and no build: only your source tree and,
  for the best name resolution, a GNAT project (`.gpr`) file.
- **QL packs** are versioned bundles of QL code. This project publishes two:
  `peter-villadsen/ada-all`, the library (classes such as `Subprogram`, `Call` and
  `Expr`, plus control flow, data flow and taint tracking), and
  `peter-villadsen/ada-queries`, ready-to-run queries built on it.
- **The CodeQL CLI** is GitHub's command-line tool. It runs the extractor and evaluates
  queries. It is not part of this project: you install it yourself, once, under
  GitHub's own terms (see [License](#license)).

If you know CodeQL from another language, an Ada query reads the same way as one for
Java or C#. The parts specific to Ada are project discovery, the quality of name
resolution, and the limitations listed at the end.

### Why

CodeQL has no Ada support from GitHub, although Ada is the language of much of the
high-assurance software (avionics, defence, rail) where static analysis matters most.
Libadalang parses all of Ada 2022 and resolves names from GNAT project files without
running a compiler, which is what makes an extractor without a build possible.
[DECISIONS.md](../DECISIONS.md) records the reasoning behind each design choice, and
[BURNDOWN.md](../BURNDOWN.md) the project's history.

### Status

The project is pre-1.0. The extractor, the library and 32 queries are tested on a
five-project corpus of real Ada code, but the database format can still change between
releases, so expect to rebuild databases when you upgrade.
[known-limitations.md](known-limitations.md) lists what doesn't work yet. Bug reports,
false positives and missed results are welcome as
[issues](https://github.com/peter-villadsen/codeql-ada/issues).

### License

[MIT](../LICENSE) for this project's own code (extractor, dbscheme, QL packs, queries).
The CodeQL CLI is proprietary and licensed separately by GitHub, under the
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
Libadalang is Apache-2.0. The release tarball bundles Libadalang's runtime and its
dependencies under their own licenses (several are GPLv3 with the GCC Runtime Library
Exception, which permits bundling them with MIT code); see
[extractors/ada/THIRD_PARTY_NOTICES.md](../extractors/ada/THIRD_PARTY_NOTICES.md).

---

## Setting up

### Requirements

| Requirement | Details |
|---|---|
| Operating system | Linux x86-64 with glibc 2.38 or newer: Ubuntu 24.04, Debian 13, Fedora 39 or later. On Windows, use WSL (below). There is no native Windows, macOS or arm64 build yet (D-010). |
| Python | 3.11 or newer, on `PATH`. The system Python is fine: the extractor needs no packages beyond what the tarball bundles. |
| CodeQL CLI | 2.25.6. Other versions are not tested, and a newer one may refuse the database (D-012). |
| GNAT (optional) | Only for source trees without a `.gpr` file, to give the extractor the runtime library's specs. See [The GNAT runtime](#the-gnat-runtime-auto-provider-only). |

### On Windows: WSL

Everything below runs in a Linux distribution under WSL. From PowerShell:

```powershell
wsl --install -d Debian
```

Then open the Debian shell and continue with the Linux steps. Your Windows drives are
under `/mnt/c/...`, but extraction is much faster on the Linux file system (`~/...`),
so copy or clone the code you analyze there.

### Installing the CodeQL CLI

Download the CLI (not the "bundle", which you don't need) from
[github/codeql-cli-binaries](https://github.com/github/codeql-cli-binaries/releases),
unpack it, and put it on `PATH`:

```sh
curl -sSLO https://github.com/github/codeql-cli-binaries/releases/download/v2.25.6/codeql-linux64.zip
unzip -q codeql-linux64.zip -d ~/tools          # creates ~/tools/codeql
echo 'export PATH="$HOME/tools/codeql:$PATH"' >> ~/.bashrc
source ~/.bashrc
codeql version
```

The last command prints `CodeQL command-line toolchain release 2.25.6.`

### Installing the Ada extractor

Download the extractor from the latest release and unpack it. It bundles the Libadalang
runtime, so nothing has to be built:

```sh
mkdir -p ~/tools/ada-extractor && cd ~/tools/ada-extractor
curl -sSLO https://github.com/peter-villadsen/codeql-ada/releases/latest/download/codeql-extractor-ada-linux64.tar.gz
tar xzf codeql-extractor-ada-linux64.tar.gz      # creates ./ada
```

The `ada/` directory is the extractor. Its **parent**, `~/tools/ada-extractor`, is what
you pass as `--search-path` to the CLI. Check that the CLI finds it:

```sh
codeql resolve languages --search-path=$HOME/tools/ada-extractor | grep ada
```

which prints `ada (/home/you/tools/ada-extractor/ada)`.

To build the tarball yourself instead (on Debian 13; see
[CONTRIBUTING.md](../CONTRIBUTING.md) for the development environment):

```sh
scripts/build-libadalang.sh          # about 45 minutes the first time
scripts/create-extractor-pack.sh     # writes codeql-extractor-ada-linux64.tar.gz
```

### Getting the query packs

The packs are published on the GitHub Container Registry. The CLI downloads a pack the
first time a command names it, or you can download it ahead of time:

```sh
codeql pack download peter-villadsen/ada-queries
```

This also downloads `peter-villadsen/ada-all` and the shared CodeQL packs it depends on,
into `~/.codeql/packages`. Use the packs of the same release as the extractor: the
library and the database format change together.

### Editor support (optional)

The [CodeQL extension for VS Code](https://codeql.github.com/docs/codeql-for-visual-studio-code/)
runs queries from the editor, shows results next to the source, and shows the tree of a
file ([Seeing the tree](#seeing-the-tree)). On Windows, install it in VS Code's WSL
window, and point its `codeQL.cli.executablePath` setting at the CLI you installed, so
that it does not download a different version.

---

## Analyzing a project

Analysis takes two commands: one builds a database from the source, the other runs
queries against it.

### Creating a database

```sh
codeql database create mydb --language=ada --build-mode=none \
  --search-path=$HOME/tools/ada-extractor --source-root=<path to your Ada project>
```

| Parameter | Meaning |
|---|---|
| `mydb` | The directory to create the database in. It must not exist yet (add `--overwrite` to replace one). |
| `--language=ada` | Which extractor to run. |
| `--build-mode=none` | There is nothing to build (below). |
| `--search-path` | The directory that contains the extractor's `ada/` directory. |
| `--source-root` | The top of the source tree to analyze. The extractor finds every Ada file under it. |

`--build-mode=none` is not a shortcut; it is how this extractor works. Most CodeQL
extractors watch a compiler run (a "traced build") to learn which files exist and how
they depend on each other. This one doesn't: Libadalang resolves Ada's semantics (what a
name refers to, what type an expression has) directly from your GNAT project file,
without running GNAT. There is no `--command` to pass and no compiler to install.

The command prints a summary line per file and ends with `Successfully created database
at ...`. The database holds a copy of the source, so results can be shown without the
original tree.

### Project discovery and name-resolution quality

The extractor looks for a GNAT project in three steps, each a fallback for the one
before:

1. **The `gpr` option**: `--extractor-option ada.gpr=<path>` (or the environment
   variable `CODEQL_EXTRACTOR_ADA_GPR`) names the `.gpr` to use. Use it in a repository
   with several `.gpr` files, where step 2 cannot choose for you.
2. **A single `.gpr` under the source root**: if exactly one `.gpr` file exists
   anywhere under `--source-root`, the extractor uses it.
3. **Auto unit provider**: with no `.gpr` (none found, or several and no option),
   Libadalang parses every `.ads`, `.adb` and `.ada` file under the source root (and any
   extensions you add, below) as one flat set, with no project configuration.

All three extract successfully; this is not a failure path. What changes is the
**quality of name resolution**. With a real `.gpr`, references between units resolve
against exactly the sources and configuration the project declares. With the auto
provider, resolution is best-effort over whatever Ada files are present, and references
into code that is not on disk (a separate library, a dependency not checked out) don't
resolve. Queries that follow names or types (`getReferencedDecl()`, `getType()`, calls,
data flow) find less. If your results look thin, a working `.gpr` is the first thing to
set up.

The extractor prints what it chose at the start of its output (`[ada-extractor]
project: …`, then the scenario, or the file extensions it reads).

### Extractor options

Every option is given on the `codeql database create` command line as
`--extractor-option ada.<name>=<value>` (short: `-O ada.<name>=<value>`), or as the
environment variable `CODEQL_EXTRACTOR_ADA_<NAME>`; the command line wins. A malformed
value stops the extraction with a message naming the option.

| Option | Meaning |
|---|---|
| `gpr` | The `.gpr` project to extract (see above). |
| `scenario` | Scenario variables, as gprbuild's `-X`: `NAME=VALUE` pairs separated by commas, e.g. `MODE=release,OS=linux`. |
| `target` | The project's target, as gprbuild's `--target` (e.g. `arm-eabi`). |
| `rts` | The project's runtime, as gprbuild's `--RTS` (e.g. `light-cortex-m4`). |
| `config` | A configuration project (`.cgpr`), as gprbuild's `--config`. |
| `charset` | The sources' character set, e.g. `iso-8859-1` (Libadalang's default) or `utf-8`. |
| `extensions` | Without a project: extensions besides `.ads`, `.adb` and `.ada` to read as Ada sources, e.g. `.a,.spc,.bdy`. A project lists its own sources, through its `Naming` package. |
| `runtime` | Without a project: a directory with the runtime's specs (see below). |
| `jobs` | The number of extraction workers (see [Parallelism](#parallelism)). |

The first five load the project the way `gprbuild` would with the same switches, so a
project that needs `-XMODE=release` to build needs `-O ada.scenario=MODE=release` to be
extracted with the sources that build uses.

### With GNAT

A project built with GNAT (or GNAT Pro, or through Alire) already has what the extractor
needs: a `.gpr` file, and a toolchain on the `PATH` that tells Libadalang where the
runtime is. Give the extractor the same project and switches you give `gprbuild`.

```sh
# gprbuild -P app.gpr -XMODE=release --target=arm-eabi --RTS=light-cortex-m4
codeql database create app-db --language=ada --build-mode=none \
  --search-path=$HOME/tools/ada-extractor --source-root=. \
  -O ada.gpr=app.gpr -O ada.scenario=MODE=release \
  -O ada.target=arm-eabi -O ada.rts=light-cortex-m4
```

- **The toolchain must be found** the way `gprbuild` finds it: put GNAT's `bin` on the
  `PATH` of the process that runs `codeql database create` (in CI, the step's
  environment). Without it, Libadalang cannot locate the runtime for the project, and
  names that refer to runtime units (`Ada.*`, `System.*`) do not resolve.
- **Dependencies** the project `with`s must be on disk, at the paths the project gives
  (`GPR_PROJECT_PATH` works as for `gprbuild`). An Alire crate's dependencies are where
  `alr build` put them; run `alr build` (or `alr update`) once first.
- **Several projects in one repository**: extract each root project into its own
  database, or use an aggregate project. A project with no `Main` is fine: every source
  of the project is extracted.
- **No `.gpr` at all** (a few sources, a script, an exercise): leave out `gpr`. The
  auto unit provider reads every Ada file under the source root, and finds the runtime
  through `gcc -print-file-name=adainclude` when GNAT is installed.

### With DDC-I Ada (and other non-GNAT compilers)

The extractor does not run a compiler: Libadalang reads the source and resolves names
itself. So code written for another compiler — DDC-I's, or any other vendor's — can be
analyzed without that compiler and without converting the build. What such a code base
lacks is a GNAT project file, so the extractor has to be told where the sources are and
what they are named. **We have not yet run it on a DDC-I code base**; the steps below are
what the extractor supports, and the list of differences is what to check first. Please
report what fails.

**Option A — without a project (quickest).** Point `--source-root` at the source tree and
name the file extensions the code base uses:

```sh
codeql database create legacy-db --language=ada --build-mode=none \
  --search-path=$HOME/tools/ada-extractor --source-root=src \
  -O ada.extensions=.a,.ada -O ada.charset=iso-8859-1
```

Every file with those extensions is read, and **a file may hold several compilation
units** (a package spec and its body, or many packages), as is common outside GNAT: the
units are found by parsing, not by file name. The names resolve across all of them.

**Option B — with a small project file (better resolution).** A `.gpr` describing just
the source directories and naming lets Libadalang look units up the way GNAT would:

```ada
--  legacy.gpr, next to the sources; not used to build anything
project Legacy is
   for Source_Dirs use ("src/**");
   package Naming is
      for Spec_Suffix ("Ada") use ".spc";   --  the code base's own extensions
      for Body_Suffix ("Ada") use ".bdy";
   end Naming;
end Legacy;
```

```sh
codeql database create legacy-db --language=ada --build-mode=none \
  --search-path=$HOME/tools/ada-extractor --source-root=. -O ada.gpr=legacy.gpr
```

A project expects one compilation unit per file, named after the unit. A code base with
several units per file either uses Option A, or is split once with GNAT's `gnatchop`
(into a copy, for analysis only).

**What to check, in order of how much it matters:**

1. **The predefined and vendor units.** `Standard`, `System`, `Ada.*` and the compiler's
   own packages are DDC-I's, not GNAT's. Without their specs, names that refer to them do
   not resolve. Without a project, point `runtime` at a directory holding the specs of
   the predefined units the code uses (`-O ada.runtime=<dir>`; a copy of the specs from
   the DDC-I installation, or GNAT's `adainclude` for the standard `Ada.*` units).
   `Standard` is always Libadalang's (GNAT's sizes for `Integer`, `Long_Integer`, …), so a
   query that depends on a type's size or range sees GNAT's.
2. **Ada 83 code using later reserved words.** Libadalang parses current Ada. An Ada 83
   identifier spelled `protected`, `tagged`, `abstract`, `aliased`, `requeue`, `until`,
   `interface`, `overriding`, `synchronized` or `some` is a parse error in the file that
   uses it. Each is recorded as a `parse-error` diagnostic and the rest of the file is
   recovered as far as possible ([Parse errors and diagnostics](#parse-errors-and-diagnostics));
   check the diagnostics before trusting results for those files.
3. **The source encoding.** Older code is often Latin-1; set `charset` if comments or
   string literals use characters outside ASCII.
4. **Implementation-defined pragmas and attributes** parse and are kept in the tree, but
   have no meaning to the analysis (a vendor's `pragma Inline_Only`, say). Machine-code
   insertions and representation clauses are parsed as written.
5. **Generic and separate units** resolve as long as their files are among the sources.

The queries themselves are compiler-independent: they work on the Ada the code is
written in. Queries about GNAT-specific things (`pragma Warnings`, GNAT `finally` parts)
simply find nothing.

### The GNAT runtime (auto provider only)

In auto-provider mode the extractor also needs the specs of the GNAT runtime
(`Ada.*`, `Interfaces.*`, `GNAT.*`, `System.*`). Without them, Libadalang fails to
resolve any statement that mentions a runtime entity, *including your own names in that
statement*, which shows up as false positives in queries such as
`ada/unused-parameter`. The runtime is found by:

1. **The `runtime` option** (or `CODEQL_EXTRACTOR_ADA_RUNTIME`): a directory containing
   the runtime's `.ads` files (GNAT's `adainclude`).
2. **`gcc -print-file-name=adainclude`**: works whenever a GNAT toolchain is installed
   (`apt install gnat` on Debian and Ubuntu).

If neither gives a directory, extraction still succeeds, but records a `no-runtime`
warning diagnostic (and prints it) saying resolution is degraded. A `.gpr` project
finds its runtime through the toolchain itself, so none of this applies to steps 1 and
2 of project discovery.

### Predefined pseudo-sources

Package `Standard` and the runtime units your code refers to *directly* are extracted
too, so that `Float`, `Constraint_Error` or `Ada.Text_IO.Put_Line` resolve to real
declarations (D-026). They are marked as predefined: `Standard` appears at the pseudo
path `/__codeql_ada_predefined__/standard.ads`, runtime units at their real paths, and
no query reports anything inside them. Units reached only through the runtime itself
are not extracted. The extractor's summary line reports their number as
`predefined_files`.

### Parallelism

Extraction runs one file per worker process; the **`jobs`** option (or
`CODEQL_EXTRACTOR_ADA_JOBS`) sets the number of workers (default: the number of CPUs). Each worker loads its own Libadalang
context and re-parses the units its file depends on, so the speed-up is real but less
than linear: 228 s at one job, 76.6 s at 12 jobs on a 345-file project. Set it to `1` to
debug the extraction of one file.

### Parse errors and diagnostics

A file that doesn't parse cleanly does not fail the extraction. Each parse error
becomes a row in the database's `diagnostics` relation, tagged `parse-error`, and the
file contributes whatever tree Libadalang could recover.

Name-resolution failures are different. If resolving a reference raises an internal
Libadalang error, the extractor counts it and moves on, and that reference simply has
no resolution in the database. These are not recorded as diagnostics; they show up in
the per-file summary line as `nameres_errors` in the `{'nodes': ..., 'xref': ..., ...}`
counters. If a query finds less than expected in one file, check that line before
assuming the query is wrong.

### Running the shipped queries

```sh
codeql database analyze mydb peter-villadsen/ada-queries \
  --format=sarif-latest --output=results.sarif
```

| Parameter | Meaning |
|---|---|
| `mydb` | The database. |
| `peter-villadsen/ada-queries` | What to run: a pack name (all its queries), a pack name with a version (`peter-villadsen/ada-queries@0.3.0`), a directory, or a single `.ql` file. |
| `--format` | `sarif-latest` for tools (GitHub code scanning, editors), `csv` for a quick look. |
| `--output` | Where to write the results. |
| `--threads`, `--ram` | Optional: evaluation threads (`0` means one per core) and memory in MB. |

The queries in `peter-villadsen/ada-queries`:

| Query id | Name | Severity |
|---|---|---|
| `ada/actual-parameters` | Unchecked conversion as an actual parameter | recommendation |
| `ada/allocators` | Questionable allocator | recommendation |
| `ada/aspects` | Boolean aspect without a value | recommendation |
| `ada/boolean-literal-comparison` | Comparison with boolean literal | recommendation |
| `ada/command-line-injection` | Command built from a command-line argument | error |
| `ada/comments` | End of long record not named | recommendation |
| `ada/dead-local-subprogram` | Dead local subprogram | warning |
| `ada/direct-recursion` | Direct recursion | recommendation |
| `ada/empty-loop-body` | Empty loop body | warning |
| `ada/exception-swallowing` | Exception handler swallows all exceptions | warning |
| `ada/float-equality` | Floating-point equality comparison | warning |
| `ada/function-missing-return` | Function missing return | error |
| `ada/goto-statement` | Goto statement | recommendation |
| `ada/hardcoded-credential` | Hardcoded credential | error |
| `ada/identical-operands` | Identical operands in boolean expression | warning |
| `ada/indirect-recursion` | Indirect recursion | recommendation |
| `ada/open-without-close` | Open without Close | warning |
| `ada/path-injection` | Uncontrolled data used in path expression | error |
| `ada/pragma-suppress` | Suppressed runtime checks | warning |
| `ada/raise-predefined-exception` | Raising a predefined exception | recommendation |
| `ada/self-comparison` | Self-comparison | warning |
| `ada/spark-mode-off` | SPARK_Mode disabled | warning |
| `ada/sql-injection` | SQL query built from user-controlled sources | error |
| `ada/todo-comment` | TODO/FIXME comment | recommendation |
| `ada/unchecked-conversion` | Use of Unchecked_Conversion | warning |
| `ada/unchecked-deallocation` | Use of Unchecked_Deallocation | warning |
| `ada/unreachable-statement` | Unreachable statement | warning |
| `ada/unused-parameter` | Unused parameter | recommendation |
| `ada/unused-local` | Unused local object | recommendation |
| `ada/unused-with-clause` | Unused with clause | recommendation |
| `ada/useless-if` | Useless if statement | warning |
| `ada/warnings-off` | Blanket disabling of compiler warnings | recommendation |

Each query's `@description` (in `ql/src/queries/`) says what it flags and why.
`ada/path-injection` and `ada/sql-injection` are new since v0.2.0, as is
`Subprogram.getMetrics()`, used in [Example 4](#example-4-cyclomatic-complexity).

### Reading the results

SARIF is a JSON format that most tools read: open `results.sarif` in VS Code with the
[SARIF Viewer](https://marketplace.visualstudio.com/items?itemName=MS-SarifVSCode.sarif-viewer)
extension, upload it to GitHub code scanning ([below](#running-in-cicd-pipelines)), or
read it with `jq`:

```sh
jq -r '.runs[].results[] | "\(.ruleId)  \(.locations[0].physicalLocation.artifactLocation.uri):\(.locations[0].physicalLocation.region.startLine)  \(.message.text)"' results.sarif
```

With `--format=csv`, each row is the query's name and description, the severity, the
message, and the file, start line and column, end line and column.

### Rebuilding after an upgrade (pre-1.0)

There is no upgrade path between database formats before 1.0 (D-011): after upgrading
the extractor or the packs, re-run `codeql database create`. A database built by an
older release may fail to load with "the database is not compatible with a QL library".
Writing upgrade scripts for a schema that is still changing would be wasted effort; the
policy will be revisited at 1.0.

---

## Ad-hoc queries

The shipped queries are a starting point. The reason to use CodeQL is that you can ask
your own questions: "which subprograms are recursive?", "which are too complex?", "can
data from the network reach this procedure?". This section shows how, around one small
Ada program and a series of queries of increasing difficulty. Every query and every output in
this section is a test in this repository (`ql/test/examples/UserGuide/` and
`ql/test/examples/SqlInjectionCustomSink/`), so they are known to work as shown.

For the QL language itself, GitHub's
[QL tutorials](https://codeql.github.com/docs/writing-codeql-queries/ql-tutorials/)
teach predicates, classes, aggregates and recursion in an hour, and the
[QL language reference](https://codeql.github.com/docs/ql-language-reference/) is the
place to look things up.

### A query pack for your queries

A query has to live in a QL pack that declares which library it uses. Create one, and
add the Ada library to it:

```sh
mkdir ~/my-ada-queries && cd ~/my-ada-queries
codeql pack init my-org/my-ada-queries           # creates my-ada-queries/qlpack.yml
cd my-ada-queries
codeql pack add peter-villadsen/ada-all          # adds the dependency and downloads it
```

`qlpack.yml` now reads:

```yaml
library: false
warnOnImplicitThis: false
name: my-org/my-ada-queries
version: 0.0.1
dependencies:
  peter-villadsen/ada-all: ^0.3.0
```

with the latest version of the library. Use the same version as the extractor; the
examples below need 0.3.0 or later. Put your `.ql` files in this directory. (If you work from a clone of this repository
instead, you can skip the pack and pass `--additional-packs=<repo>/ql` to the commands
below, so that the CLI finds `ada-all` in the clone.)

### Running a query

`codeql query run` evaluates one query and prints its results as a table:

```sh
codeql query run --database=metrics-db CallsItself.ql
```

| Parameter | Meaning |
|---|---|
| `--database` (`-d`) | The database to query. |
| `CallsItself.ql` | The query file. Its pack's `qlpack.yml` says which library it imports. |
| `--output` (`-o`) | Optional: write the results to a `.bqrs` file (CodeQL's binary result format) instead of printing them. |
| `--additional-packs` | Optional: directories to search for packs before the package cache, such as a clone of this repository's `ql/` directory. |
| `--threads`, `--ram` | Optional, as for `database analyze`. |

A `.bqrs` file converts to CSV or JSON:

```sh
codeql query run --database=metrics-db --output=complexity.bqrs CyclomaticComplexity.ql
codeql bqrs decode --format=csv complexity.bqrs
```

`query run` works for any query. To get SARIF or CSV with locations, as for the shipped
queries, use `codeql database analyze mydb MyQuery.ql --format=sarif-latest --output=...`;
that needs a query whose metadata says `@kind problem` or `@kind path-problem`
([Query metadata](query-writing.md#query-metadata-and-kind)).

### The example program

The first examples run against this program, `metrics.adb`:

```ada
procedure Metrics is
   function Fact (N : Natural) return Natural is
   begin
      if N = 0 then
         return 1;
      else
         return N * Fact (N - 1);
      end if;
   end Fact;

   procedure Ping (N : Natural);

   procedure Pong (N : Natural) is
   begin
      if N > 0 then
         Ping (N - 1);
      end if;
   end Pong;

   procedure Ping (N : Natural) is
   begin
      Pong (N);
   end Ping;

   function Score (Text : String) return Natural is
      Total : Natural := 0;
   begin
      for C of Text loop
         case C is
            when 'a' .. 'z' => Total := Total + 1;
            when '0' .. '9' => Total := Total + 2;
            when others     => null;
         end case;
         exit when Total > 100 and then C = '.';
      end loop;
      return Total;
   exception
      when Constraint_Error =>
         return 0;
   end Score;
begin
   Pong (Fact (3) + Score ("abc"));
end Metrics;
```

Build a database from it:

```sh
mkdir -p ~/guide/src && cp metrics.adb ~/guide/src/
cd ~/guide
codeql database create metrics-db --language=ada --build-mode=none \
  --search-path=$HOME/tools/ada-extractor --source-root=src
```

### Seeing the tree

Before writing a query, look at what the code you want to find turns into. The usual
way to write a rule is: write a small example of the code you want to flag, build a
database from it, print its tree, and read the classes and accessors your query needs
off the tree.

`tools/PrintAst.ql` in `ada-all` prints the tree of every file in a database. Copy it
from the package cache into your query pack, and run it there (in a clone of this
repository it is `ql/lib/tools/PrintAst.ql`):

```sh
cp ~/.codeql/packages/peter-villadsen/ada-all/<version>/tools/PrintAst.ql .
codeql query run --database=metrics-db PrintAst.ql
```

(Running it in the package cache fails: a pack there has no lock file, so its
dependencies don't resolve.)

The output has a row per node. Here is the part for `Fact`'s `else` branch,
`return N * Fact (N - 1);`:

```
| metrics.adb |  48 | 7:10  |   [0]: ReturnStmt                                    |
| metrics.adb |  49 | 7:17  |     getReturnExpr: BinOp                             |
| metrics.adb |  50 | 7:17  |       getLeft: Identifier N -> Metrics.Fact.N        |
| metrics.adb |  51 | 7:19  |       getOp: OpMult *                                |
| metrics.adb |  52 | 7:21  |       getRight: CallExpr -> Metrics.Fact             |
| metrics.adb |  53 | 7:21  |         getName: Identifier Fact -> Metrics.Fact     |
| metrics.adb |  54 | 7:27  |         getSuffix: AssocList                         |
| metrics.adb |  55 | 7:27  |           [0]: ParamAssoc                            |
| metrics.adb |  56 | 7:27  |             getRExpr: BinOp                          |
```

Each line is `accessor: Class token -> resolved declaration`, indented by depth, with
the line and column of the node. Read it as QL: the return statement's
`getReturnExpr()` is a `BinOp`, whose `getRight()` is a `CallExpr`, whose `getName()` is
the identifier `Fact`, which resolves to the declaration `Metrics.Fact`. `[i]` is the
`i`th element of a list, reached with `getChild(i)`.

Two things are worth knowing:

- **The tree is Libadalang's**, and some Ada constructs parse differently from what
  you'd guess: a type conversion `T (X)` and an array index `A (I)` are `CallExpr`s too,
  and a call without arguments is just an `Identifier`. Don't guess the shape; print it.
  [ast-reference.md](ast-reference.md) lists the common shapes and the traps.
- **For many questions there is a semantic class** that hides the shape. A call is a
  `Call` whichever form it takes (with or without parentheses, an operator, a prefixed
  view `Obj.Op`); a subprogram is a `Subprogram` whether it is declared once or twice
  (spec and body). Use the tree to find out what you are looking at, then prefer the
  semantic class when there is one. [query-writing.md](query-writing.md#the-library)
  lists them.

For one file of a large database, `scripts/print_ast.py <db> --file <name>` prints
the same tree for that file only, as text, JSON or XML. In VS Code, **CodeQL: View AST**
shows it next to the source ([Seeing the tree](query-writing.md#seeing-the-tree) in the
query-writing guide has the steps).

### Example 1: a subprogram that calls itself

The tree shows a call to `Fact` inside `Fact`. In terms of the semantic classes: a
`Call` whose target (`getTarget()`) is the subprogram it is written in (`getCaller()`).
`CallsItself.ql`:

```ql
/**
 * @name Subprogram calls itself
 * @description A call from a subprogram to itself: direct recursion.
 * @kind problem
 * @id my-app/calls-itself
 * @problem.severity recommendation
 */

import ada

from Call c, Subprogram s
where
  c.fromSource() and
  s = c.getCaller() and
  c.getTarget() = s
select c, "This call is to $@, the subprogram it is in.", s, s.getName()
```

The parts of a query:

- The **metadata** comment names the query and says what kind of result it gives.
  `@kind problem` means each result is an element and a message, which is what
  `database analyze` turns into SARIF alerts.
- `import ada` brings in the library.
- `from` declares variables and their types, `where` states what must hold, `select`
  says what to report. In the message, `$@` is replaced by a link to the next element
  (`s`), labelled with the one after it (`s.getName()`).
- `c.fromSource()` restricts the results to your own code. A database holds more than
  your code: so that names such as `Integer` or `Ada.Text_IO.Put_Line` resolve, the
  extractor also extracts package `Standard` and the specs of the GNAT runtime units
  your code refers to, as full syntax trees marked "predefined"
  ([Predefined pseudo-sources](#predefined-pseudo-sources)). `fromSource()` holds for
  an element in one of your files, not in one of those. Without it, a query that lists
  subprograms would also list every subprogram in the spec of `Ada.Text_IO`, if your
  code `with`s it. CodeQL for Java has the same predicate for the same reason: there it
  leaves out the classes read from library `.jar` files. Apply it to what you
  *report*, not to everything the query looks at: a query may follow a call into the
  runtime, but should report only places in your code.

```sh
codeql query run --database=metrics-db CallsItself.ql
```

```
|     c      |                     col1                     |  s   | col3 |
+------------+----------------------------------------------+------+------+
| Fact (...) | This call is to $@, the subprogram it is in. | Fact | Fact |
```

It finds the call in `Fact`. It does not find `Ping` and `Pong`, which call each other:
neither contains a call to itself.

### Example 2: recursion at any depth

`Ping` calls `Pong`, which calls `Ping`. To find that, describe the call graph as a
predicate, `calls(caller, callee)`, and ask whether a subprogram reaches itself in one
or more steps. QL writes "one or more steps" as `calls+`, the transitive closure:
`calls+(s, s)` holds when `s` calls itself directly, or through any number of other
subprograms. `RecursiveAtAnyDepth.ql`:

```ql
/**
 * @name Recursive subprogram
 * @description A subprogram that can call itself, directly or through other
 *              subprograms.
 * @kind problem
 * @id my-app/recursive
 * @problem.severity recommendation
 */

import ada

/** Holds if `caller` contains a call to `callee`. */
predicate calls(Subprogram caller, Subprogram callee) {
  exists(Call c | c.getCaller() = caller and c.getTarget() = callee)
}

from Subprogram s, string how
where
  s.fromSource() and
  calls+(s, s) and
  if calls(s, s) then how = "directly" else how = "through other subprograms"
select s, "This subprogram calls itself " + how + "."
```

`exists(Call c | ...)` introduces a local variable: there is a call `c` such that... .
Run it with `database analyze` to get results with locations, as a CI pipeline would:

```sh
codeql database analyze metrics-db RecursiveAtAnyDepth.ql --format=csv --output=recursive.csv
```

```
"Recursive subprogram","A subprogram ...","recommendation","This subprogram calls itself directly.","/metrics.adb","2","4","9","13"
"Recursive subprogram","A subprogram ...","recommendation","This subprogram calls itself through other subprograms.","/metrics.adb","11","4","11","33"
"Recursive subprogram","A subprogram ...","recommendation","This subprogram calls itself through other subprograms.","/metrics.adb","13","4","18","13"
```

`Fact` directly, `Ping` and `Pong` through each other; not `Score` or `Metrics`. `Ping`
is reported at line 11, its spec: a `Subprogram` is the first declaration of a
subprogram, so a subprogram with a separate spec is reported there. The shipped queries
`ada/direct-recursion` and `ada/indirect-recursion` are fuller versions of these two
examples, and [query-writing.md](query-writing.md#example-recursion-at-any-depth) has
one that also names the next subprogram on the cycle.

Like every query built on `Call`, this sees calls whose target is known statically: a
dispatching call counts as a call to the operation it names, and a call through an
access-to-subprogram value is not a `Call`. The data-flow library follows both.

### Example 3: counting statements

Metrics are aggregates. `count(...)` counts the values that satisfy a condition; here,
the statements whose enclosing subprogram is `s`. `getEnclosingSubprogram()` gives the
*innermost* one, so a statement in a subprogram nested in another counts for the nested
one only. `StatementCount.ql`:

```ql
/**
 * @name Statements per subprogram
 * @description The number of statements in each subprogram's body, not counting
 *              those of subprograms nested in it.
 * @kind table
 * @id my-app/statement-count
 */

import ada

from Subprogram s, int statements
where
  s.fromSource() and
  statements = count(Stmt st | st.getEnclosingSubprogram() = s)
select s, statements order by statements desc
```

New here:

- **Syntax classes.** `Stmt` is a class of the tree, one per Libadalang node kind, the
  ones `PrintAst.ql` shows: `IfStmt`, `ReturnStmt`, `AssignStmt` and the rest are all
  `Stmt`s. Use them where the semantic classes stop, as a Java query uses `IfStmt` or
  `LoopStmt`.
- **`@kind table`**: the result is a table, not alerts. Run it with `query run`.

```
| Score   | 8 |
| Fact    | 3 |
| Pong    | 2 |
| Metrics | 1 |
| Ping    | 1 |
```

`Score` has eight: the `for` loop, the `case`, the two assignments, `null`, `exit`, and
the two `return`s (one in the exception handler). A compound statement counts once,
plus the statements inside it.

For comparison, CodeQL for Java writes the same query as
`count(Stmt st | st.getEnclosingCallable() = c)`. The library also has the count built
in, as `s.getMetrics().getNumberOfStatements()` (below).

### Example 4: cyclomatic complexity

McCabe's cyclomatic complexity is one more than the number of decisions in a body: the
number of independent paths through it. In Ada the decisions are `if` and `elsif`
(statements and expressions), `while` and `for` loops, `exit when`, short-circuit
`and then` and `or else`, quantified expressions, each `case` alternative after the
first, and each exception handler. Each of these is a node kind in the tree, so the
query lists them and counts them like the statements above.
`CyclomaticComplexity.ql`:

```ql
/**
 * @name Cyclomatic complexity
 * @description McCabe's cyclomatic complexity of each subprogram: one more than the
 *              number of decisions in its body.
 * @kind table
 * @id my-app/cyclomatic-complexity
 */

import ada

/** Holds if `d` is a point where control takes one of two or more ways. */
predicate decision(AdaNode d) {
  d instanceof IfStmt or
  d instanceof ElsifStmtPart or
  d instanceof IfExpr or
  d instanceof ElsifExprPart or
  d instanceof WhileLoopStmt or
  d instanceof ForLoopStmt or
  d instanceof QuantifiedExpr or
  d instanceof ExceptionHandler or
  exists(d.(ExitStmt).getCondExpr()) or
  d.(BinOp).getOp() instanceof OpAndThen or
  d.(BinOp).getOp() instanceof OpOrElse or
  // each alternative of a `case` after the first
  (d instanceof CaseStmtAlternative or d instanceof CaseExprAlternative) and
  not d = d.getParent().getChild(0)
}

from Subprogram s, int complexity
where
  s.fromSource() and
  complexity = 1 + count(AdaNode d | decision(d) and d.getEnclosingSubprogram() = s)
select s, complexity order by complexity desc
```

New here:

- `x instanceof C` holds when `x` is a `C`; `x.(C)` is `x` viewed as a `C`, so that
  `C`'s accessors can be used (`d.(ExitStmt).getCondExpr()`: the condition of an exit
  statement, which exists only for `exit when`).
- `getChild(0)` is the first element of a list: the `[0]` in the printed tree.

```
"s","complexity"
"Score",7
"Fact",2
"Pong",2
"Metrics",1
"Ping",1
```

`Score` is 7: one, plus the `for` loop, two `case` alternatives after the first, the
`exit when`, the `and then`, and the exception handler.

Writing the predicate yourself is how you would count differently (some tools leave out
exception handlers, for instance). The library computes the standard measure, as
CodeQL for Java does with `getMetrics().getCyclomaticComplexity()`: `getMetrics()`
gives `getNumberOfStatements()` and `getCyclomaticComplexity()` for any `Subprogram`
(it also counts the alternatives of a `select` after the first). With it, a rule that
flags complex subprograms is a few lines. `ComplexSubprogram.ql`:

```ql
/**
 * @name Complex subprogram
 * @description A subprogram whose cyclomatic complexity is above a threshold.
 * @kind problem
 * @id my-app/complex-subprogram
 * @problem.severity recommendation
 */

import ada

from Subprogram s, int complexity
where
  s.fromSource() and
  complexity = s.getMetrics().getCyclomaticComplexity() and
  complexity > 5
select s, "This subprogram has cyclomatic complexity " + complexity + "."
```

It reports `Score`: "This subprogram has cyclomatic complexity 7." A real project would
pick a higher threshold; 10 to 15 is common.

### Example 5: SQL injection, with sources, sinks and barriers

The questions so far are about the shape of the code. Security questions are about
where values go: can data from the network end up in the text of an SQL statement?
That is **taint tracking**: following a value from a *source* (where untrusted data
enters) to a *sink* (where it does harm), through assignments, parameters, function
results, concatenation and so on, and stopping at a *barrier* (a function that makes
the value safe).

The library describes each role as a class, and the shipped queries are built from
those classes. For SQL injection, `codeql.ada.security.SqlInjection` has three:

| Class | Role | Defined by the library as |
|---|---|---|
| `SqlInjection::Source` | where untrusted data enters | data received from the network (`RemoteFlowSource`: `GNAT.Sockets`, AWS request data) |
| `SqlInjection::Sink` | where it does harm | the `Query` string of `GNATCOLL.SQL.Exec.Execute`, `Fetch`, `Insert_And_Get_PK` and `Prepare` |
| `SqlInjection::Barrier` | where it becomes safe | nothing: a project adds its own |

These classes are **extension points**: each is abstract, so its members are the union
of all its subclasses, and you add to a role by writing a subclass. A query that imports
your subclass sees your sink alongside the library's. This is how you teach the analysis
about your own code: most projects run SQL through their own layer, not GNATCOLL
directly.

Say the project's database layer is the package `Db`:

```ada
package Db is
   procedure Run (Sql : String);
   --  Runs an SQL statement.

   function Quote (S : String) return String;
   --  S as an SQL string literal, with its quotes doubled.
end Db;
```

and a server uses it:

```ada
with GNAT.Sockets; use GNAT.Sockets;
with Db;

procedure Server is
   Sock : Socket_Type;

   procedure Delete_User (Name : String) is
   begin
      Db.Run ("DELETE FROM users WHERE name = '" & Name & "'");      --  flagged
   end Delete_User;

   procedure Delete_User_Safely (Name : String) is
   begin
      Db.Run ("DELETE FROM users WHERE name = " & Db.Quote (Name));  --  not flagged
   end Delete_User_Safely;

   Name : constant String := String'Input (Stream (Sock));
begin
   Delete_User (Name);
   Delete_User_Safely (Name);
   Db.Run ("DELETE FROM users WHERE id = 1");                        --  not flagged
end Server;
```

`Name` is read from a socket, so it is a source already. The query adds `Db.Run`'s
`Sql` argument as a sink and `Db.Quote`'s result as a barrier, and reports every path
from a source to a sink. `SqlInjectionCustomSink.ql`:

```ql
/**
 * @name SQL statement built from network data
 * @description Data received from the network becomes part of the text of an SQL
 *              statement run by the in-house database layer `Db`.
 * @kind path-problem
 * @id my-app/sql-injection
 * @problem.severity error
 * @tags security
 */

import ada
import codeql.ada.security.SqlInjection
import SqlInjection::Flow::PathGraph

/** The text of a statement run by `Db.Run`: a sink. */
class DbRunSql extends SqlInjection::Sink {
  DbRunSql() {
    exists(Call c | c.getTarget().hasQualifiedName("Db.Run") |
      this.asExpr() = c.getArgumentByName("Sql")
    )
  }
}

/** A value quoted by `Db.Quote`, safe inside a statement: a barrier. */
class DbQuoted extends SqlInjection::Barrier {
  DbQuoted() {
    exists(Call c | c.getTarget().hasQualifiedName("Db.Quote") | this.asExpr() = c)
  }
}

from SqlInjection::Flow::PathNode source, SqlInjection::Flow::PathNode sink
where
  SqlInjection::Flow::flowPath(source, sink) and
  sink.getNode().asExpr().fromSource()
select sink.getNode(), source, sink, "This SQL statement depends on $@.", source.getNode(),
  source.getNode().(SqlInjection::Source).getSourceType()
```

How it works:

- **A class with a characteristic predicate.** `DbRunSql() { ... }` says which values
  belong to the class: the data-flow nodes that are the `Sql` argument of a call to
  `Db.Run`. `hasQualifiedName` identifies the subprogram by meaning, not by text, so
  `use` clauses, renamings and prefixed views are all covered.
- **Data-flow nodes.** Flow is between nodes, not expressions; `this.asExpr()` is the
  expression a node stands for.
- **`SqlInjection::Flow`** is the library's taint-tracking configuration, built from
  the three classes. `flowPath(source, sink)` holds when tainted data can get from
  `source` to `sink`, across subprograms (here into `Delete_User` through its
  parameter).
- **`@kind path-problem`** and `import SqlInjection::Flow::PathGraph` make each result a
  path: the select gives the alert's location, the start and end of the path, and the
  message. In SARIF, and in VS Code, you can step through the path.

```sh
codeql database analyze server-db SqlInjectionCustomSink.ql \
  --format=sarif-latest --output=sql.sarif
```

It reports one result, the statement in `Delete_User`, with the path
`String'Input (...)` → `Name` (the argument of `Delete_User`) → `Name` (the parameter)
→ `"DELETE ... '" & Name & "'"`. `Delete_User_Safely` is not reported, because the
value passes through `Db.Quote`. Delete the `DbQuoted` class and it is reported too:
taint flows through `Quote`'s body, character by character, into its result.

To use your extensions with the shipped query instead of writing a query, put the
classes in a `.qll` file and write a copy of `ql/src/queries/SqlInjection.ql` that
imports it. The same pattern works for the other security queries
(`CommandInjection::Sink`, `PathInjection::Sink`, ...) and for new sources:
[query-writing.md](query-writing.md#sources-of-untrusted-data) shows how to add a
`RemoteFlowSource` for a web framework the library doesn't model, and
[Data flow and taint tracking](query-writing.md#data-flow-and-taint-tracking) has more
complete examples, including one written from scratch with
`TaintTracking::Global`.

### Testing your queries

A query you rely on deserves a test, in the same way as code. A test is a directory with
some Ada, the query (or a `.qlref` file naming it), and the expected results in a
`.expected` file; `codeql test run <dir>` builds a database from the Ada, runs the query
and compares. [Testing a query](query-writing.md#adding-a-query) in the query-writing
guide has the steps.

---

## Running in CI/CD pipelines

### The idea

Running the analysis on your machine finds problems in code that is already written.
Running it in your CI/CD pipeline finds them when they are introduced: on every pull
request, before the change is merged, and on a schedule, so that new queries find old
problems. The pipeline runs the same two commands as you would by hand, plus steps to
install the tools and to do something with the results:

1. **Install the tools**, at pinned versions: the CodeQL CLI (2.25.6) and the Ada
   extractor of a given release. Cache them; they don't change between runs.
2. **Create the database** from the checked-out source, with `--build-mode=none`.
   There is no build to run and no compiler to install.
3. **Analyze** with the query pack, writing SARIF.
4. **Publish** the results where developers see them, and optionally **gate**: fail or
   flag the build when there are findings.

Steps 1 to 3 are the same on any CI system. Step 4 depends on the provider. Three things
apply everywhere:

- **Check the license.** Running the CodeQL CLI in CI on code that is not open source
  requires a license from GitHub ([License](#license)), whichever CI system runs it.

- **Pin both versions** and upgrade them together, deliberately. The CLI, the extractor
  and the packs are a matched set (D-012), and pinning means a change in findings comes
  from your code, not from someone else's release.
- **Use a Linux x86-64 agent** with glibc 2.38 or newer (Ubuntu 24.04 or later).

One thing surprises everyone on GitHub: **you cannot add `ada` to the languages of
`github/codeql-action/init`**. The CodeQL Action only knows the languages GitHub ships
extractors for. A third-party extractor installs the CLI itself and runs it in ordinary
shell steps; only the final upload uses the CodeQL Action, whose `upload-sarif` accepts
SARIF from any tool. Once uploaded, Ada alerts look like any other code scanning alerts.

### GitHub Actions

On GitHub, results go to **code scanning**: the repository's Security tab lists them,
and pull requests show the new ones as annotations on the changed lines. Code scanning
is available on public repositories, and on private ones with GitHub Advanced Security.

Save this as `.github/workflows/codeql-ada.yml` in the repository to analyze:

```yaml
name: CodeQL (Ada)

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '30 2 * * 1'        # weekly, so new queries also look at old code

permissions:
  contents: read
  security-events: write         # required to upload to code scanning

jobs:
  analyze:
    runs-on: ubuntu-24.04
    timeout-minutes: 60
    env:
      CODEQL_CLI_VERSION: 2.25.6
      ADA_EXTRACTOR_VERSION: v0.3.0
      ADA_QUERY_PACK: peter-villadsen/ada-queries@0.3.0

    steps:
      - uses: actions/checkout@v4

      - name: Cache the CodeQL CLI and the Ada extractor
        id: tools-cache
        uses: actions/cache@v4
        with:
          path: |
            ~/codeql-cli
            ~/ada-extractor
          key: codeql-${{ env.CODEQL_CLI_VERSION }}-ada-${{ env.ADA_EXTRACTOR_VERSION }}

      - name: Install the CodeQL CLI and the Ada extractor
        if: steps.tools-cache.outputs.cache-hit != 'true'
        run: |
          set -euo pipefail
          curl -sSL -o /tmp/codeql.zip \
            "https://github.com/github/codeql-cli-binaries/releases/download/v${CODEQL_CLI_VERSION}/codeql-linux64.zip"
          mkdir -p ~/codeql-cli && unzip -q /tmp/codeql.zip -d ~/codeql-cli
          curl -sSL -o /tmp/ada.tar.gz \
            "https://github.com/peter-villadsen/codeql-ada/releases/download/${ADA_EXTRACTOR_VERSION}/codeql-extractor-ada-linux64.tar.gz"
          mkdir -p ~/ada-extractor && tar -xzf /tmp/ada.tar.gz -C ~/ada-extractor

      - name: Add CodeQL to PATH
        run: echo "$HOME/codeql-cli/codeql" >> "$GITHUB_PATH"

      - name: Download the query pack
        run: codeql pack download "$ADA_QUERY_PACK"

      - name: Create the database
        run: |
          codeql database create "$RUNNER_TEMP/ada-db" --language=ada --build-mode=none \
            --search-path="$HOME/ada-extractor" --source-root=.

      - name: Analyze
        run: |
          codeql database analyze "$RUNNER_TEMP/ada-db" "$ADA_QUERY_PACK" \
            --format=sarif-latest --output=ada-results.sarif

      - name: Upload to code scanning
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: ada-results.sarif
          category: ada               # keeps Ada alerts apart from other analyses
```

Notes:

- **`category: ada`** matters when the repository also has another CodeQL analysis:
  without separate categories, each upload replaces the other's alerts.
- **A repository with several `.gpr` files** should set `CODEQL_EXTRACTOR_ADA_GPR` on
  the "Create the database" step ([Project discovery](#project-discovery-and-name-resolution-quality)).
- **Your own queries** run alongside: check in your query pack and add its directory
  to the `analyze` command after the pack name.
- **Without code scanning**, replace the upload with `actions/upload-artifact` to keep
  the SARIF, and gate on it as in the Azure DevOps example below.

### Azure DevOps

Azure DevOps Pipelines runs the same steps. It has no Security tab, so there are two
ways to make results visible: the free **SARIF SAST Scans Tab** extension from the
Visual Studio Marketplace, which shows SARIF in a "Scans" tab on the build when it is
published in a build artifact named exactly `CodeAnalysisLogs`; and gating, which marks
the build when there are findings. (GitHub Advanced Security for Azure DevOps has its
own CodeQL tasks, but like the CodeQL Action they only know GitHub's languages.)

Save this as `azure-pipelines.yml`:

```yaml
trigger:
  branches:
    include: [main]

pr:
  branches:
    include: [main]

schedules:
  - cron: '30 2 * * 1'
    displayName: Weekly
    branches:
      include: [main]
    always: true

pool:
  vmImage: ubuntu-24.04

variables:
  CODEQL_CLI_VERSION: 2.25.6
  ADA_EXTRACTOR_VERSION: v0.3.0
  ADA_QUERY_PACK: peter-villadsen/ada-queries@0.3.0
  TOOLS_DIR: $(Pipeline.Workspace)/ada-tools

steps:
  - checkout: self

  - task: Cache@2
    displayName: Cache the CodeQL CLI and the Ada extractor
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
      curl -sSL -o /tmp/ada.tar.gz \
        "https://github.com/peter-villadsen/codeql-ada/releases/download/$(ADA_EXTRACTOR_VERSION)/codeql-extractor-ada-linux64.tar.gz"
      tar -xzf /tmp/ada.tar.gz -C "$(TOOLS_DIR)/extractor"
    displayName: Install the CodeQL CLI and the Ada extractor
    condition: ne(variables.TOOLS_CACHED, 'true')

  - script: echo "##vso[task.prependpath]$(TOOLS_DIR)/cli/codeql"
    displayName: Add CodeQL to PATH

  - script: codeql pack download "$(ADA_QUERY_PACK)"
    displayName: Download the query pack

  - script: |
      codeql database create "$(Agent.TempDirectory)/ada-db" --language=ada --build-mode=none \
        --search-path="$(TOOLS_DIR)/extractor" --source-root="$(Build.SourcesDirectory)"
    displayName: Create the database

  - script: |
      mkdir -p "$(Build.ArtifactStagingDirectory)/CodeAnalysisLogs"
      codeql database analyze "$(Agent.TempDirectory)/ada-db" "$(ADA_QUERY_PACK)" \
        --format=sarif-latest \
        --output="$(Build.ArtifactStagingDirectory)/CodeAnalysisLogs/ada.sarif"
    displayName: Analyze

  - task: PublishBuildArtifacts@1
    displayName: Publish the SARIF
    condition: always()
    inputs:
      PathtoPublish: $(Build.ArtifactStagingDirectory)/CodeAnalysisLogs
      ArtifactName: CodeAnalysisLogs     # the name the Scans tab looks for

  - script: |
      sarif="$(Build.ArtifactStagingDirectory)/CodeAnalysisLogs/ada.sarif"
      count=$(jq '[.runs[].results[]] | length' "$sarif")
      echo "Ada findings: $count"
      if [ "$count" -gt 0 ]; then
        echo "##vso[task.logissue type=warning]Ada analysis reported $count finding(s)"
        echo "##vso[task.complete result=SucceededWithIssues;]"
      fi
    displayName: Report findings
```

Notes:

- **`$(VAR)` is Azure DevOps substitution**, done before the script runs; `$VAR` is
  the shell's. The pipeline uses `$(...)` for pipeline variables only.
- **Keep the database out of the sources directory** (`$(Agent.TempDirectory)`), or the
  next extraction picks it up as source.
- **Start by marking the build `SucceededWithIssues`**, not failing it. Quality rules
  over an existing codebase find things on the first day, and a pipeline that goes red
  at once tends to be switched off rather than fixed. Once the findings are dealt with,
  change to `result=Failed`, or gate on one rule or severity only:
  `jq '[.runs[].results[] | select(.level == "error")] | length'`.
- **Self-hosted and air-gapped agents**, common where Ada is used, can't download
  anything: stage the CLI, the extractor and the packs (including the shared CodeQL
  packs) in advance. [ci-integration.md](ci-integration.md#air-gapped-agents) has the
  verified procedure.

---

## Known limitations

- **Same-kind-same-span node merging.** A node's identity in the database is computed
  from its file, kind and source span, which is what makes references between files
  possible without a counter shared by worker processes. Two different nodes of the
  same kind at exactly the same span would therefore become one. This has not been seen
  to affect any shipped query or the test corpus.
- **Generic instances.** The database has no expanded copy of a generic for each
  instantiation: an instantiation links to the generic it instantiates, and a call to
  an instance (`procedure P is new G (...)`, then `P (X)`) resolves to `G`. Data flow
  follows such a call into the generic's body, but there is one body for all instances.
- **Data-flow approximations.** The data-flow and taint-tracking library follows values
  across subprograms, through dispatching calls, calls through access-to-subprogram
  values, entry calls, record components, array elements, standard containers and
  shared variables, some of them coarsely: all elements of an array count as one, and
  shared variables ignore the order of calls. The control-flow graph runs a GNAT
  `finally` part however its sequence is left; the queries that follow paths take only
  the ways it really continues.
  [known-limitations.md](known-limitations.md) lists each approximation and what it
  means for a query's results.

---

## Troubleshooting

### Installation and setup

| Symptom | Cause and fix |
|---|---|
| `Could not find extractor for language ada` / `Unknown language: ada` | `--search-path` points at the `ada/` directory instead of its parent, or not at the extractor at all. Check with `codeql resolve languages --search-path=...`. |
| `version 'GLIBC_2.38' not found` during extraction | The system's glibc is too old (Debian 12, Ubuntu 22.04, ...). Use a newer distribution, or WSL with Debian 13 or Ubuntu 24.04. |
| `python3: command not found`, or a syntax error from the extractor | Python 3.11 or newer must be on `PATH` as `python3`. Check with `python3 --version`. |
| `codeql: command not found` | The CLI's directory is not on `PATH` (`~/tools/codeql` in the setup above). |
| Extraction is very slow under WSL | The source is on a Windows drive (`/mnt/c/...`). Copy it to the Linux file system. |

### Creating databases

| Symptom | Cause and fix |
|---|---|
| Many `ada/unused-parameter` or `ada/unused-local` results on names that are plainly used; a `no-runtime` warning | No `.gpr` file was used, and no GNAT runtime was found. Install GNAT (`apt install gnat`), set `CODEQL_EXTRACTOR_ADA_RUNTIME`, or better, point the extractor at your `.gpr` ([The GNAT runtime](#the-gnat-runtime-auto-provider-only)). |
| Fewer results than expected; references don't resolve | The extractor fell back to the auto provider: no `.gpr`, or several. Set `CODEQL_EXTRACTOR_ADA_GPR`. Check the summary lines for `nameres_errors` and parse errors ([Parse errors and diagnostics](#parse-errors-and-diagnostics)). |
| `parse-error` diagnostics | Libadalang could not parse part of a file; the rest of the file is still extracted. Check that the file compiles. Code that needs preprocessing (`gnatprep`) has to be preprocessed first. |
| `Please specify a different location, or use the --overwrite flag` | The database directory exists. Add `--overwrite`, or remove it. |
| The database contains files you didn't mean to analyze | Everything under `--source-root` is extracted. Narrow the source root, or use a `.gpr` that lists your source directories. |

### Running queries

| Symptom | Cause and fix |
|---|---|
| `The CodeQL database is not compatible with a QL library` / `dbscheme mismatch` | The database was built by a different release than the packs. Rebuild the database with the matching extractor ([Rebuilding after an upgrade](#rebuilding-after-an-upgrade-pre-10)). In CI, the CLI, extractor and packs must be the pinned set. |
| `could not resolve module ada` / `Could not resolve library path` | The query is not in a pack that depends on `peter-villadsen/ada-all`, or its dependencies are not installed. Run `codeql pack install` in the pack's directory, or pass `--additional-packs=<repo>/ql` when working from a clone ([A query pack for your queries](#a-query-pack-for-your-queries)). |
| `Pack 'codeql/...' was not found in the pack download cache` | A lock file pins a version but the pack is not on disk. Run `codeql pack install` (or `codeql pack download` for a query pack) first. |
| `the cache directory is already locked` | VS Code has the database open, and its query server locks it. Close the database in VS Code, or run on a copy. |
| `Query produced no results` | Check that the code is what you think it is: print the tree ([Seeing the tree](#seeing-the-tree)) and check names with `hasQualifiedName`, which wants the fully qualified name (`My_App.Db.Run`, not `Run`). A nested subprogram's name includes its parent's (`Outer.Inner`). |
| A query reports results inside `Ada.*` or `Standard` | Add `x.fromSource()` for what you report. |
| `database analyze` fails to interpret a query's results | `analyze` needs a query whose metadata says `@kind problem` or `@kind path-problem`. Run `@kind table` queries with `codeql query run`. |
| `Referenced pack ... was not found locally, and no lock file is present` | The query is in a pack whose dependencies were not installed, such as one in the package cache. Run `codeql pack install` in your pack, and run queries from there. |
| Evaluation runs out of memory or is slow on a large database | Give it more memory with `--ram=<MB>` and threads with `--threads=0`. A data-flow query with very broad sources or sinks costs more than a syntactic one. |

### CI/CD

| Symptom | Cause and fix |
|---|---|
| `Unrecognized language: ada` in `codeql-action/init` | The CodeQL Action can't run third-party extractors. Install the CLI and run it in shell steps ([Running in CI/CD pipelines](#running-in-cicd-pipelines)). |
| `Resource not accessible by integration` when uploading | The workflow lacks `security-events: write` in `permissions:`. |
| `Advanced Security must be enabled` when uploading | Code scanning is not available on the repository. Keep the SARIF as an artifact instead. |
| Alerts from another analysis disappear after the Ada upload | Missing or shared `category:`. Give each analysis its own. |
| The Scans tab in Azure DevOps is empty | The artifact must be named exactly `CodeAnalysisLogs`, and the SARIF SAST Scans Tab extension installed in the organization. |
| `codeql pack download` fails on a self-hosted agent | The agent cannot reach `ghcr.io`. Vendor the packs ([Air-gapped agents](ci-integration.md#air-gapped-agents)). |

### Reporting a problem

If none of this helps, or a query gives a wrong result, open an
[issue](https://github.com/peter-villadsen/codeql-ada/issues). The templates ask for what
helps most: the versions of the CLI and the extractor, the command, the output, and,
for a false positive or a missed result, a small piece of Ada that shows it. Check
[known-limitations.md](known-limitations.md) first: an approximation listed there is
known, though a real-world case that it affects is still worth reporting.
