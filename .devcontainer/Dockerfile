ARG VARIANT=24-trixie
FROM node:${VARIANT}

ARG TZ
ENV TZ="$TZ"

ARG USERNAME=node

ARG NPM_GLOBAL=/usr/local/share/npm-global

# Add NPM global to PATH
ENV PATH=${NPM_GLOBAL}/bin:${PATH}
# Set NPM_global as prefix
RUN npm config -g set prefix ${NPM_GLOBAL}

# Install node packages
ARG NODE_PACKAGES="eslint tslint-to-eslint-config typescript"
RUN npm install -g ${NODE_PACKAGES} \
	&& npm cache clean --force > /dev/null 2>&1

# For persisting bash history
RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/cmdhistory/.bash_history" \
	&& mkdir /cmdhistory \
	&& touch /cmdhistory/.bash_history \
	&& chown -R $USERNAME /cmdhistory \
	&& echo "$SNIPPET" >> "/home/$USERNAME/.bashrc"

USER $USERNAME

# Install Claude
ARG CLAUDE_CODE_VERSION=latest
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION}

# For persisting claude config
RUN mkdir -p /home/$USERNAME/.claude

# Run selected build scripts
ARG BUILD_SCRIPTS=""
RUN mkdir /home/$USERNAME/devcontainer-build-scripts
COPY build-scripts/* /home/$USERNAME/devcontainer-build-scripts/
RUN cd /home/$USERNAME/devcontainer-build-scripts/ && ./build.sh

WORKDIR "/workspace"