#!/bin/bash

# Pre-creating paths since `nono` policy rules can't operate on things that don't exist yet
# Not doing this in Dockerfile during build or during post-create since:
# 1. `/tmp` gets wiped every time the container spins-down due to `/tmp` on `debian:trixie`
#   is mounted as an in-memory, tmpfs
# 2. prefer to keep all the related "pre-created" stuff together
mkdir -p /home/$USER/.docker
mkdir -p /tmp/claude-$UID
mkdir -p /tmp/nono-compose
