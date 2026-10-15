FROM debian:trixie

ARG TZ
ENV TZ="$TZ"

RUN apt-get update && apt-get install -y --no-install-recommends \
	adduser \
	ca-certificates \
	curl \
	git \
	unzip \
	make \
	&& apt-get clean && rm -rf /var/lib/apt/lists/*

# Install GitHub CLI
# https://github.com/cli/cli/releases
ARG GH_VERSION=latest
RUN VERSION=$(if [ "$GH_VERSION" = "latest" ]; \
	then curl -sIL https://github.com/cli/cli/releases/latest | grep -i location | tail -n 1 | grep -oP 'v\K[0-9a-zA-Z.-]+'; \
	else echo ${GH_VERSION}; \
	fi) \
	&& ARCH=$(dpkg --print-architecture) \
	&& echo "\$VERSION: ${VERSION}, \$ARCH: ${ARCH}" \
	&& curl -fL -O https://github.com/cli/cli/releases/download/v${VERSION}/gh_${VERSION}_linux_${ARCH}.deb \
	&& curl -fL -O https://github.com/cli/cli/releases/download/v${VERSION}/gh_${VERSION}_checksums.txt \
	&& grep " gh_${VERSION}_linux_${ARCH}.deb\$" gh_${VERSION}_checksums.txt | sha256sum -c - \
	&& dpkg -i gh_${VERSION}_linux_${ARCH}.deb \
	&& rm gh_${VERSION}_linux_${ARCH}.deb gh_${VERSION}_checksums.txt

# Install nono for locking down running of agents
# https://nono.sh/docs/cli/getting_started/installation#debian/ubuntu
ARG NONO_VERSION=latest
RUN VERSION=$(if [ "$NONO_VERSION" = "latest" ]; \
	then curl -sIL https://github.com/always-further/nono/releases/latest | grep -i location | tail -n 1 | grep -oP 'v\K[0-9a-zA-Z.-]+'; \
	else echo ${NONO_VERSION}; \
	fi) \
	&& ARCH=$(dpkg --print-architecture) \
	&& echo "\$VERSION: ${VERSION}, \$ARCH: ${ARCH}" \
	&& curl -fL -O https://github.com/always-further/nono/releases/download/v${VERSION}/nono-cli_${VERSION}_${ARCH}.deb \
	&& curl -fL -O https://github.com/always-further/nono/releases/download/v${VERSION}/SHA256SUMS.txt \
	&& grep " nono-cli_${VERSION}_${ARCH}.deb\$" SHA256SUMS.txt | sha256sum -c - \
	&& dpkg -i nono-cli_${VERSION}_${ARCH}.deb \
	&& rm nono-cli_${VERSION}_${ARCH}.deb SHA256SUMS.txt

# Install herdr for managing agents
# https://herdr.dev/docs/install/
# - herdr publishes no checksums file, so verifying against the asset digest GitHub computes on upload
ARG HERDR_VERSION=latest
RUN VERSION=$(if [ "$HERDR_VERSION" = "latest" ]; \
	then curl -sIL https://github.com/herdrdev/herdr/releases/latest | grep -i location | tail -n 1 | grep -oP 'v\K[0-9a-zA-Z.-]+'; \
	else echo ${HERDR_VERSION}; \
	fi) \
	&& ARCH=$(case "$(dpkg --print-architecture)" in amd64) echo x86_64;; arm64) echo aarch64;; esac) \
	&& echo "\$VERSION: ${VERSION}, \$ARCH: ${ARCH}" \
	&& DIGEST=$(curl -fsSL https://api.github.com/repos/herdrdev/herdr/releases/tags/v${VERSION} | sed -n "/\"name\": \"herdr-linux-${ARCH}\"/,/\"digest\"/p" | grep -oP '"digest": "sha256:\K[0-9a-f]{64}') \
	&& curl -fL -O https://github.com/herdrdev/herdr/releases/download/v${VERSION}/herdr-linux-${ARCH} \
	&& echo "${DIGEST}  herdr-linux-${ARCH}" | sha256sum -c - \
	&& install -m 755 herdr-linux-${ARCH} /usr/local/bin/herdr \
	&& rm herdr-linux-${ARCH}

ARG USERNAME=eng-user
RUN adduser $USERNAME

# For persisting bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/cmdhistory/.bash_history" \
	&& mkdir /cmdhistory \
	&& touch /cmdhistory/.bash_history \
	&& chown -R $USERNAME /cmdhistory \
	&& echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"

USER $USERNAME

# Placeholder symlink to support switching between volume vs. mounted config directory
# - need to create `.claude-tmp` (i.e. can't just create a dangling symlink) before installing claude
#   since claude installation creates and writes to `~/.claude` directory
RUN mkdir /home/$USERNAME/.claude-tmp && ln -s /home/$USERNAME/.claude-tmp /home/$USERNAME/.claude

# Pre-create herdr's config dir so it's owned by `$USERNAME`
# - `compose.yml` bind-mounts only `config.toml` into it, and docker creates any missing parent dirs
#   of a mount target as root, which leaves herdr unable to write its logs/state next to the config
RUN mkdir -p /home/$USERNAME/.config/herdr

# Install claude code
ARG CLAUDE_CODE_VERSION=latest
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION}

# Install nono claude-code package, which also wires it into claude code as a single-plugin marketplace
# https://nono.sh/docs/cli/features/managing-packs#initializing-project-files
# https://nono.sh/docs/cli/clients/claude-code#what-%E2%80%9Cpull%E2%80%9D-actually-does
ARG NONO_CLAUDE_PACK_VERSION=latest
RUN nono pull nolabs-ai/claude@${NONO_CLAUDE_PACK_VERSION} --init
# Add nono profile that extends claude-code profile with docker support
COPY utils/claude-with-docker.jsonc /home/$USERNAME/.config/nono/profiles/

# Dedicated writable dirs for the nono sandbox when running agents
# - `NONO_SANDBOX_DIR` is more permanent - survives container spin-downs
# - `NONO_SANDBOX_TMPDIR` is more ephemeral - may not survive container spin-downs
# - referenced in: `claude` function below, `.devcontainer/nono-sandbox.env`, and `utils/post-start.sh`
ENV NONO_SANDBOX_DIR=/home/$USERNAME/nono-sandbox/
ENV NONO_SANDBOX_TMPDIR=/tmp/nono-sandbox/
# IMPORTANT: Intentionally making copy of `nono-sandbox.env` and setting permissions for security purposes
# - this file is meant to configure the nono sandbox environment for agents, so we want to prevent any
#   potentially malicious changes the agent might make from being automatically picked-up on subsequent
#   sessions (i.e. prevent an agent from self-modifying its own sandbox policy)
# - this forces a human to intentionally rebuild the devcontainer, or modify the copy before changes
#   get picked up
# - `--chmod=444` prevents `$USERNAME` from writing to it even if nono's own policy get loosened
# - do NOT add `--chown=$USERNAME` or drop `--chmod` -- `$USERNAME` owning or being able to write
#   this file would help allow the sandboxed agent to overwrite its own trusted copy
COPY --chmod=444 nono-sandbox.env /home/$USERNAME/nono-sandbox.env
# Override `claude` command to automatically run with `nono`
# - grants r+w access to /workspace
# - grants r+w access to `$NONO_SANDBOX_TMPDIR` so claude has a dedicated area to r+w to in `/tmp`
#   w/o exposing the entirety of `/tmp` -- e.g. `docker compose` sometimes r+w from `/tmp`
# - sourcing `nono-sandbox.env` provides a way to help address access issues due to tooling that r+w
#   from directories nono locks down (see `nono-sandbox.env` for further details)
# - `( … )` for running in subshell to keep vars scoped to this invocation only
# - `[ -f ]` guard to allow claude to run even w/o `nono-sandbox.env` present
# - quoted heredoc delimiter (`'EOF'`) so `$VARS` are written literally and expanded at call time
RUN cat >> "/home/$USERNAME/.bashrc" <<'EOF'
claude() (
  set -a
  [ -f ~/nono-sandbox.env ] && . ~/nono-sandbox.env
  set +a

  # using `sh -c` to create an intermediate, dumpable `sh` process so `herdr` can detect agent sessions
  # https://github.com/herdrdev/herdr/discussions/514?utm_source=chatgpt.com#discussioncomment-18274829
  HERDR_AGENT=claude sh -c '
    nono run \
      --allow /workspace/ \
      --allow "$NONO_SANDBOX_DIR" \
      --allow "$NONO_SANDBOX_TMPDIR" \
      --profile claude-with-docker \
      -- claude "$@"
  ' sh "$@"
)
EOF
# Pre-creating paths for nono policy enforcement in `utils/post-start.sh`

# Run selected build scripts
ARG BUILD_SCRIPTS=""
RUN mkdir /home/$USERNAME/devcontainer-build-scripts
COPY build-scripts/* /home/$USERNAME/devcontainer-build-scripts/
RUN cd /home/$USERNAME/devcontainer-build-scripts/ && ./build.sh

WORKDIR "/workspace"

