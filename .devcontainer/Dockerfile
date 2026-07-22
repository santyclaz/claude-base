FROM debian:trixie

ARG TZ
ENV TZ="$TZ"

RUN apt-get update && apt-get install -y --no-install-recommends \
	adduser \
	ca-certificates \
	curl \
	unzip \
	make \
	&& apt-get clean && rm -rf /var/lib/apt/lists/*

# Install nono for locking down running of claude
# https://nono.sh/docs/cli/getting_started/installation#debian/ubuntu
ARG NONO_VERSION=latest
RUN VERSION=$(if [ "$NONO_VERSION" = "latest" ]; \
	then curl -sIL https://github.com/always-further/nono/releases/latest | grep -i location | tail -n 1 | grep -oP 'v\K[0-9a-zA-Z.-]+'; \
	else echo ${NONO_VERSION}; \
	fi) \
	&& ARCH=$(dpkg --print-architecture) \
	&& echo "\$VERSION: ${VERSION}, \$ARCH: ${ARCH}" \
	&& curl -L -O https://github.com/always-further/nono/releases/download/v${VERSION}/nono-cli_${VERSION}_${ARCH}.deb \
	&& dpkg -i nono-cli_${VERSION}_${ARCH}.deb

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

# Install claude code
ARG CLAUDE_CODE_VERSION=latest
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION}

# Install nono claude-code package, which also wires it into claude code as a single-plugin marketplace
# https://nono.sh/docs/cli/features/managing-packs#initializing-project-files
# https://nono.sh/docs/cli/clients/claude-code#what-%E2%80%9Cpull%E2%80%9D-actually-does
ARG NONO_CLAUDE_PACK_VERSION=latest
RUN nono pull always-further/claude@${NONO_CLAUDE_PACK_VERSION} --init
# Add nono profile that extends claude-code profile with docker support
COPY utils/claude-with-docker.jsonc /home/$USERNAME/.config/nono/profiles/

# Dedicated writable dirs for the nono sandbox when running agents
# - `NONO_SANDBOX_DIR` is more permanent - survives container spin-downs
# - `NONO_SANDBOX_TMPDIR` is more ephemeral - may not survive container spin-downs
# - Referenced in: `claude` alias below, `.devcontainer/nono-sandbox.env`, and `utils/post-start.sh`
ENV NONO_SANDBOX_DIR=/home/$USERNAME/nono-sandbox/
ENV NONO_SANDBOX_TMPDIR=/tmp/nono-sandbox/
# Override `claude` command to automatically run with `nono`
# - grants r+w access to /workspace
# - grants r+w access to `$NONO_SANDBOX_TMPDIR` so claude has a dedicated area to r+w to in `/tmp`
#   w/o exposing the entirety of `/tmp` -- e.g. `docker compose` sometimes r+w from `/tmp`
# - sourcing `nono-sandbox.env` provides a way to help address access issues due to tooling that r+w
#   from directories nono locks down (see `nono-sandbox.env` for further details)
# - `( … )` for running in subshell to keep vars scoped to this invocation only
# - `[ -f ]` guard to allow claude to run even w/o `nono-sandbox.env` present
COPY nono-sandbox.env /home/$USERNAME/nono-sandbox.env
RUN SNIPPET="alias claude='(set -a; [ -f ~/nono-sandbox.env ] && . /workspace/.devcontainer/nono-sandbox.env; set +a; exec nono run --allow /workspace/ --allow \$NONO_SANDBOX_DIR --allow \$NONO_SANDBOX_TMPDIR --profile claude-with-docker -- claude)'" \
	&& echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"
# Pre-creating paths for nono policy enforcement in `utils/post-start.sh`

# Run selected build scripts
ARG BUILD_SCRIPTS=""
RUN mkdir /home/$USERNAME/devcontainer-build-scripts
COPY build-scripts/* /home/$USERNAME/devcontainer-build-scripts/
RUN cd /home/$USERNAME/devcontainer-build-scripts/ && ./build.sh

WORKDIR "/workspace"

