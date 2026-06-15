#!/bin/bash
# Helper to change the temp directory `docker compose` writes to
# This is to support nono + docker-compose use
# - `nono` by default doesn't support read from `/tmp`
# - `docker compose` writes + reads tmp files in `/tmp`
# - https://github.com/docker/compose/issues/4137

DOCKER_BIN=/usr/bin/docker

if [ "$1" = "compose" ] && [ -n "$NONO_COMPOSE_TMPDIR" ]; then
    TMPDIR="$NONO_COMPOSE_TMPDIR" exec "$DOCKER_BIN" "$@"
else
    # Run standard docker commands normally
    exec "$DOCKER_BIN" "$@"
fi
