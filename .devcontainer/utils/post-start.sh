#!/bin/bash

# Pre-creating paths since `nono` policy rules can't operate on things that don't exist yet
# Not doing this in Dockerfile during build or during post-create since:
# 1. `/tmp` gets wiped every time the container spins-down since `/tmp` on `debian:trixie`
#   is mounted as an in-memory, tmpfs
# 2. prefer to keep all the related "pre-created" stuff together
mkdir -p /home/$USER/.docker
mkdir -p "$NONO_SANDBOX_DIR"
mkdir -p "$NONO_SANDBOX_TMPDIR"

# Point ~/.claude to the bind-mount if provided, otherwise to the volume
if [ -n "$CLAUDE_CONFIG_MOUNT_DIR" ]; then
    ln -sfn /home/${USER}/.claude-mount /home/${USER}/.claude
    echo -e "\e[96m~/.claude\e[0m" linked to "\e[94m~/.claude-mount\e[0m" "(host path: \e[93m${CLAUDE_CONFIG_MOUNT_DIR}\e[0m)"
else
    ln -sfn /home/${USER}/.claude-volume /home/${USER}/.claude
    echo -e "\e[96m~/.claude\e[0m" linked to "\e[94m~/.claude-volume\e[0m"
fi
