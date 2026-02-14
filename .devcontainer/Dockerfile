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

# Install Claude
ARG CLAUDE_CODE_VERSION=latest
RUN npm install -g @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION}

# For persisting claude config
RUN mkdir -p /home/$USERNAME/.claude \
	&& chown -R node:node /home/$USERNAME/.claude

WORKDIR "/workspace"