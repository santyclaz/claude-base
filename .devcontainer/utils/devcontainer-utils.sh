#!/bin/bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Provides whether this is a devcontainer environment
if [[ "${REMOTE_CONTAINERS:-}" == "true" ]]; then
    DEVCONTAINER="true"
else
    DEVCONTAINER="false"
fi
export DEVCONTAINER

# Provides the hostname of the devcontainer
DEVCONTAINER_HOSTNAME="$(hostname)"
export DEVCONTAINER_HOSTNAME

# Provides the network name of the devcontainer
# Allows individual project compose files to use the devcontainer's network and allow the
# devcontainer to reach these services (e.g. via curl, etc.)
# Doing so allows AI agents to reach and test these services from within the devcontainer
DEVCONTAINER_NETWORK="${DEVCONTAINER_NETWORK:-$(docker inspect "${DEVCONTAINER_HOSTNAME}" \
  --format '{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{"\n"}}{{end}}' \
  2>/dev/null | head -n1)}"
export DEVCONTAINER_NETWORK

# Provides the path to a utility compose file meant to override the default network with the
# devcontainer's network (via above DEVCONTAINER_NETWORK)
# e.g. docker compose -f compose.yml -f "${DEVCONTAINER_NETWORK_AS_DEFAULT_COMPOSE_PATH}"
DEVCONTAINER_NETWORK_AS_DEFAULT_COMPOSE_PATH="${ROOT_DIR}/compose.devcontainer-network-as-default.yml"
export DEVCONTAINER_NETWORK_AS_DEFAULT_COMPOSE_PATH
