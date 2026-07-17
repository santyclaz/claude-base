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
# - need to create `.claude-tmp` (i.e. can't just create a dangling symlink) since claude installation
#   creates and writes to `~/.claude` directory
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
# Override `claude` command to automatically run with `nono` and allowing r+w access to /workspace
# - `GIT_CONFIG_NOSYSTEM=1` is to git from reading system level `/etc/gitconfig` which `nono` locks down
# - `NONO_SANDBOX_TMPDIR=/tmp/nono-sandbox` is to provide a dedicated area where claude can read/write to
#   in `/tmp` w/o granting read access to the entirety of `/tmp`.
#   - e.g. claude fails when running `docker compose` since the command sometimes reads/writes from `/tmp`
RUN SNIPPET="alias claude='NONO_SANDBOX_TMPDIR=/tmp/nono-sandbox/ GIT_CONFIG_NOSYSTEM=1 nono run --allow /workspace/ --allow /tmp/nono-sandbox/ --allow ~/.nono-bin/ --profile claude-with-docker -- claude'" \
	&& echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"
# Add passthrough docker binary that runs `docker compose` with an overridden TMPDIR
# This is so we don't have to provide read access to the entirety of `/tmp` which is locked down by default
COPY utils/nono-docker-compose.sh /home/$USERNAME/.nono-bin/docker
RUN SNIPPET="export PATH=\"/home/$USERNAME/.nono-bin:\$PATH\"" \
	&& echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"
# Pre-creating paths for nono policy enforcement in `utils/post-start.sh`

# Run selected build scripts
ARG BUILD_SCRIPTS=""
RUN mkdir /home/$USERNAME/devcontainer-build-scripts
COPY build-scripts/* /home/$USERNAME/devcontainer-build-scripts/
RUN cd /home/$USERNAME/devcontainer-build-scripts/ && ./build.sh

WORKDIR "/workspace"

