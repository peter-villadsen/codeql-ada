# The codeql-ada container image: the CodeQL CLI, the Ada extractor, GNAT and the query
# packs, on Debian 13 (the platform the extractor is built and tested on, D-010).
# Published to ghcr.io/peter-villadsen/codeql-ada by .github/workflows/image.yml; see
# docs/user-guide.md, "Using the container image".
#
# The build context must contain the release tarball:
#   gh release download v0.3.0 -p codeql-extractor-ada-linux64.tar.gz -D container
#   docker build --build-arg ADA_VERSION=0.3.0 -t codeql-ada container
FROM debian:13-slim

# D-012: the one CLI version the extractor and the packs are tested with.
ARG CODEQL_CLI_VERSION=2.25.6
# The extractor's version; the query packs of the same release are installed with it.
ARG ADA_VERSION

LABEL org.opencontainers.image.source="https://github.com/peter-villadsen/codeql-ada" \
      org.opencontainers.image.description="CodeQL CLI with the Ada extractor, GNAT and the codeql-ada query packs" \
      org.opencontainers.image.licenses="MIT"

# gnat: the runtime specs the extractor resolves Ada.*, System.*, ... against, and the
# toolchain a .gpr project is loaded with (gcc: the extractor and gprconfig look for
# `gcc`, which the gnat package alone installs only as gcc-14). git: to clone sources
# into a volume.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl unzip git python3 gcc gnat gprbuild \
 && rm -rf /var/lib/apt/lists/*

RUN curl -sSL -o /tmp/codeql.zip \
      "https://github.com/github/codeql-cli-binaries/releases/download/v${CODEQL_CLI_VERSION}/codeql-linux64.zip" \
 && unzip -q /tmp/codeql.zip -d /opt \
 && rm /tmp/codeql.zip

# The extractor goes into the CLI's own directory, next to its bundled extractors, so
# `--language=ada` works without --search-path.
COPY codeql-extractor-ada-linux64.tar.gz /tmp/
RUN tar xzf /tmp/codeql-extractor-ada-linux64.tar.gz -C /opt/codeql \
 && rm /tmp/codeql-extractor-ada-linux64.tar.gz

ENV PATH=/opt/codeql:$PATH

RUN test -n "$ADA_VERSION" \
 && codeql pack download "peter-villadsen/ada-queries@${ADA_VERSION}"

WORKDIR /src
ENTRYPOINT ["codeql"]
CMD ["version"]
