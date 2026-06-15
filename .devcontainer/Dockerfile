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
RUN VERSION=$(curl -sI https://github.com/always-further/nono/releases/latest | grep -i location | grep -oP 'v\K[0-9a-zA-Z.-]+') \
	&& ARCH=$(dpkg --print-architecture) \
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

# Install claude code
ARG CLAUDE_CODE_VERSION=latest
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION}

# For persisting claude config
RUN mkdir -p /home/$USERNAME/.claude

# Install nono claude-code package, which also wires it into claude code as a single-plugin marketplace
# https://nono.sh/docs/cli/features/managing-packs#initializing-project-files
# https://nono.sh/docs/cli/clients/claude-code#what-%E2%80%9Cpull%E2%80%9D-actually-does
RUN nono pull always-further/claude --init
# Add nono profile that extends claude-code profile with docker support
COPY utils/claude-with-docker.jsonc /home/$USERNAME/.config/nono/profiles/
# Override `claude` command to automatically run with `nono` and allowing r+w access to /workspace
# - `NONO_COMPOSE_TMPDIR=/tmp/nono-compose` is a workaround so claude can run docker compose w/o granting
#   read access to the entirety of `/tmp`. This works in conjunction with `nono-docker-compose.sh` below.
RUN SNIPPET="alias claude='NONO_COMPOSE_TMPDIR=/tmp/nono-compose/ nono run --allow /workspace/ --allow /tmp/nono-compose/ --allow ~/.nono-bin/ --profile claude-with-docker -- claude'" \
	&& echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"
# Add passthrough docker binary that runs `docker compose` with an overridden TMPDIR
COPY utils/nono-docker-compose.sh /home/$USERNAME/.nono-bin/docker
RUN SNIPPET="export PATH=\"/home/$USERNAME/.nono-bin:\$PATH\"" \
	&& echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"
# Pre-creating paths for nono policy enforcement in `utils/post-create.sh`

# Run selected build scripts
ARG BUILD_SCRIPTS=""
RUN mkdir /home/$USERNAME/devcontainer-build-scripts
COPY build-scripts/* /home/$USERNAME/devcontainer-build-scripts/
RUN cd /home/$USERNAME/devcontainer-build-scripts/ && ./build.sh

WORKDIR "/workspace"

