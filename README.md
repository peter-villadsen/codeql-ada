# codeql-ada

CodeQL language support for **Ada**: an extractor built on
[Libadalang](https://github.com/AdaCore/libadalang), a database schema, QL
libraries, and queries — enabling `codeql database create --language=ada`.

> **Status: pre-alpha.** Currently executing the spike phase of
> [BURNDOWN.md](BURNDOWN.md). Nothing here is usable yet.

## Why

CodeQL has no Ada support, official or community. Libadalang parses 100% of
Ada 2022 and provides name resolution from GNAT project files (GPR) without
invoking a compiler, which makes a build-less CodeQL extractor feasible.

## Planned architecture

| Component | Approach |
|---|---|
| Extractor | Python (prototype), using the Libadalang Python API; build-less (`build_modes: none`) |
| dbscheme + QL AST classes | Generated from Libadalang/Langkit node introspection |
| Semantic depth (v1) | AST + name resolution (xref) + expression types; CFG/dataflow later in QL |
| Project discovery | GPR project files, falling back to Libadalang's auto unit provider |

See [DECISIONS.md](DECISIONS.md) for rationale and [BURNDOWN.md](BURNDOWN.md)
for the full plan.

## License

[MIT](LICENSE). Note that the CodeQL CLI itself is proprietary and licensed
separately by GitHub; users must obtain it under the
[GitHub CodeQL Terms](https://github.com/github/codeql-cli-binaries/blob/main/LICENSE.md).
Libadalang is Apache-2.0.
