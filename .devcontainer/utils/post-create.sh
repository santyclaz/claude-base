#!/bin/bash

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "source ${ROOT_DIR}/devcontainer-utils.sh" >> ~/.bashrc
