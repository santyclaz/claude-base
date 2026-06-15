#!/bin/bash

# Pre-creating paths since `nono` policy rules can't operate on things that don't exist yet
# Not doing this in Dockerfile during build since:
# 1. `/tmp` effectively gets wiped after build since `/tmp` on `debian:trixie` is mounted, in-memory (tmpfs)
# 2. prefer to keep all the related
mkdir -p /home/$USER/.docker
mkdir -p /tmp/claude-$UID
mkdir -p /tmp/nono-compose
