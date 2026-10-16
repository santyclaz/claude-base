#!/bin/bash
# Regression tests for the nono sandbox profile (`utils/claude-with-docker.jsonc`): the session's own
# restrictions plus its command sandboxes (`git` / `ssh` / `gh`, ...)
#
# USAGE (from a regular, unsandboxed terminal in the devcontainer):
#   .devcontainer/tests/sandbox/run.sh [--with-writes] [group...]
#
#   - re-launches itself under `nono run` the same way the `claude` wrapper in the Dockerfile does, but
#     with the REPO copy of the profile (no need to copy it to `~/.config/nono/profiles/` first);
#     `NONO_PROFILE=<name|path>` overrides, e.g. `NONO_PROFILE=claude-with-docker` for the installed copy
#   - groups: one per file in `cases/` (default: all, `session` first) -- add a group by adding a file
#   - `--with-writes`: also run checks with remote side effects (pushes + deletes a throwaway branch)
#
# Already inside a nono sandbox (e.g. run by claude) it runs in place against the *running* profile.
#
# Checks are read-only by default. Groups whose preconditions aren't met (not logged in to gh, no ssh
# agent, ...) are skipped, not failed. Login state can only be checked from a regular terminal, so
# in-session runs assume every tool is logged in.

set -u

HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
DEVCONTAINER=$(cd "$HERE/../.." && pwd)

case " $* " in
  *" -h "*|*" --help "*) sed -n '2,/^$/s/^# \{0,1\}//p' "$0"; exit 0 ;;
esac

# --- re-launch under nono (mirrors `claude()` in the Dockerfile) ---
if [ -z "${NONO_CAP_FILE:-}" ]; then
  command -v nono >/dev/null || { echo "nono not found" >&2; exit 2; }

  # login state is checked here, outside the sandbox -- from inside, the only way to check is through the
  # very command sandboxes under test, so a broken sandbox would look "logged out" and get skipped
  logged_in=()
  [ -s ~/.config/gh/hosts.yml ] && logged_in+=(gh)
  export SANDBOX_TESTS_LOGGED_IN="${logged_in[*]}"

  set -a
  [ -f ~/nono-sandbox.env ] && . ~/nono-sandbox.env
  set +a
  exec nono run --silent \
    --allow /workspace/ \
    --allow "$NONO_SANDBOX_DIR" \
    --allow "$NONO_SANDBOX_TMPDIR" \
    --profile "${NONO_PROFILE:-$DEVCONTAINER/utils/claude-with-docker.jsonc}" \
    -- bash "$HERE/run.sh" "$@"
fi

. "$HERE/lib.sh"

WITH_WRITES=0
SELECTED=()
for arg in "$@"; do
  case $arg in
    --with-writes) WITH_WRITES=1 ;;
    *) SELECTED+=("$arg") ;;
  esac
done
if [ ${#SELECTED[@]} -eq 0 ]; then
  SELECTED=(session)
  for f in "$HERE"/cases/*.sh; do
    g=$(basename "$f" .sh)
    [ "$g" = session ] || SELECTED+=("$g")
  done
fi

# the repo these tests live in -- used for gh/git checks that need a real github remote
REPO=$(git -C "$DEVCONTAINER" rev-parse --show-toplevel)
REMOTE=$(git -C "$REPO" remote | head -n 1)
REMOTE_URL=$(git -C "$REPO" remote get-url "$REMOTE")

# scratch dir inside the sandbox tmp dir (what `TMPDIR` points to in sessions)
SCRATCH=$(mktemp -d "${NONO_SANDBOX_TMPDIR%/}/sandbox-tests.XXXXXX") || exit 2
trap 'rm -rf "$SCRATCH"' EXIT

INSTALLED=~/.config/nono/profiles/claude-with-docker.jsonc
if [ -f "$INSTALLED" ] && ! cmp -s "$INSTALLED" "$DEVCONTAINER/utils/claude-with-docker.jsonc"; then
  printf '%sNOTE:%s installed profile differs from the repo copy -- results reflect whichever profile this ran under\n' "$C_SKIP" "$C_OFF"
fi

for g in "${SELECTED[@]}"; do
  f="$HERE/cases/$g.sh"
  [ -f "$f" ] || { echo "unknown group: $g" >&2; exit 2; }
  . "$f"
done

summary
