# .devcontainer

A Debian-trixie based [Dev Container](https://containers.dev/) preinstalled with
[Claude Code](https://claude.ai/code), sandboxed with [nono](https://nono.sh/), and configured with
[Docker-in-Docker (DinD)](https://github.com/devcontainers/features/tree/main/src/docker-in-docker),
so containers launched inside the workspace run on their own isolated daemon.

> **Why DinD over DooD?** Docker-outside-of-Docker mounts the host socket, which runs as root by
> default — giving the container effective root on the host machine. DinD's `--privileged`
> requirement is more contained, and nono further restricts what Claude Code can access at runtime.
> An alternative is DinD with the [sysbox](https://github.com/nestybox/sysbox) runtime, which
> eliminates the `--privileged` requirement entirely.

## Configuration (`.env`)

Per-user overrides live in `.devcontainer/.env`. All values are optional; changes take effect on
the next container **rebuild**.

| Variable                  | Default               | Effect                                                                                                                                                                                                     |
| ------------------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TZ`                      | `America/Los_Angeles` | Container timezone.                                                                                                                                                                                        |
| `CLAUDE_CODE_VERSION`     | `latest`              | Claude Code version to install during image build.                                                                                                                                                         |
| `NONO_VERSION`            | `latest`              | nono CLI version to install during image build.                                                                                                                                                            |
| `NONO_CLAUDE_PACK_VERSION`| `latest`              | nono claude pack version to install during image build.                                                                                                                                                    |
| `CLAUDE_CONFIG_MOUNT_DIR` | _(empty)_             | Host path to bind-mount as the container's Claude config directory. When set, overrides the default named-volume persistence — see below.                                                                  |
| `BUILD_SCRIPTS`           | _(empty)_             | Space-separated list of installers from `build-scripts/` to run during image build (`.sh` suffix optional). Available: `install-bun`, `install-node`. Example: `BUILD_SCRIPTS="install-bun install-node"`. |

### Claude config persistence

Inside the container, `~/.claude` is a symlink that resolves at container start to one of two
targets, depending on whether `CLAUDE_CONFIG_MOUNT_DIR` is set:

- **Named Docker volume** _(default)_ — `~/.claude` → `~/.claude-volume`. The volume survives
  container rebuilds but is lost if explicitly pruned (e.g. `docker volume prune`).
- **Host bind-mount** — set `CLAUDE_CONFIG_MOUNT_DIR` in `.env` to a host path (e.g.
  `CLAUDE_CONFIG_MOUNT_DIR=~/.claude`) and `~/.claude` → `~/.claude-mount`, which is bind-mounted
  from that host path. Useful for sharing your host's Claude config (auth, settings, history) into
  the container.

## nono security sandbox

Claude Code runs wrapped in [nono](https://nono.sh/), which enforces filesystem and network
policies at runtime. The `claude` command is aliased to:

```sh
(set -a; [ -f ~/nono-sandbox.env ] && . ~/nono-sandbox.env; set +a; exec nono run --allow /workspace/ --allow $NONO_SANDBOX_DIR --allow $NONO_SANDBOX_TMPDIR --profile claude-with-docker -- claude)
```

- **`/workspace/`** — read+write access to your project files.
- **`$NONO_SANDBOX_DIR`** (`~/nono-sandbox/`) — a dedicated read+write scratch dir that survives
  container spin-downs.
- **`$NONO_SANDBOX_TMPDIR`** (`/tmp/nono-sandbox/`) — the ephemeral counterpart, in `/tmp`, so tools
  that need to r+w there don't require exposing all of `/tmp`.
- **`nono-sandbox.env`** — sourced into the subshell before `nono run`, so tools can be pointed at
  the sandbox dirs above or have access to locked-down paths disabled. Currently sets
  `GIT_CONFIG_NOSYSTEM=1` (stops git reading the system-level `/etc/gitconfig`, which nono locks
  down) and `TMPDIR=$NONO_SANDBOX_TMPDIR` (redirects tools that read/write temp files to `/tmp` by
  default, e.g. [`docker compose`](https://github.com/docker/compose/issues/4137)). Add more
  `VAR=value` lines there as needed — see the file's header comment for format details.

  > **Security note:** the alias sources `~/nono-sandbox.env` — a copy baked into the image at build
  > time (root-owned, read-only), *not* the live `.devcontainer/nono-sandbox.env` in your workspace.
  > This is deliberate: `/workspace/` is writable by the sandboxed agent, so if the alias sourced
  > the live file directly, an agent could edit its own sandbox policy and have the change apply on
  > the very next `claude` invocation. Because the trusted copy only updates on rebuild, treat edits
  > to `.devcontainer/nono-sandbox.env` like any other sandbox-policy change (same scrutiny as
  > `utils/claude-with-docker.jsonc`) — review the diff carefully *before* rebuilding.
- **`claude-with-docker` profile** — extends the built-in `claude-code` nono pack with additional
  access needed for Docker operations (`$HOME/.docker`, Docker CLI plugin paths). The profile lives
  at `utils/claude-with-docker.jsonc`; edit it to adjust what Claude Code can access. Note that the
  profile explicitly **denies** `/vscode/vscode-server/bin` to prevent the VS Code IDE integration
  from running outside the sandbox.

> The `anthropic.claude-code` VS Code extension is intentionally **not** installed — it would run
> Claude Code outside the nono sandbox. Use the `claude` CLI instead.

## Adding a build script

Drop an executable `.sh` file into `build-scripts/` and add its name (`.sh` suffix optional) to
`BUILD_SCRIPTS` in `.env`. It runs once during image build as `eng-user`.

Currently available scripts:

- `install-bun` — installs the [Bun](https://bun.com/) JavaScript runtime.
- `install-node` — installs [Node.js v24](https://nodejs.org/) via [nvm](https://github.com/nvm-sh/nvm).

## Troubleshooting

### Verbose build output

The default Dev Container build output swallows most messages. To see everything:

```sh
docker compose build --no-cache --progress=plain
```

### OAuth / login issues

If `claude` can't complete authentication, IPv6 may be causing the OAuth callback to fail. The
`compose.yml` already disables IPv6 inside the container via
`sysctls: net.ipv6.conf.all.disable_ipv6=1`. If you're still seeing issues, verify the sysctl
took effect:

```sh
sysctl net.ipv6.conf.all.disable_ipv6
# Expected: net.ipv6.conf.all.disable_ipv6 = 1
```

### Claude config lost after rebuild

Config is stored in a named Docker volume. If the volume was deleted (e.g. via `docker volume prune`),
you'll need to re-authenticate with `claude`. To see which volume is mounted:

```sh
docker inspect <container-name> --format '{{json .Mounts}}'
```

### nono policy denials

If a Claude Code tool call is blocked by nono, a policy error is printed to the terminal. To
investigate or relax the policy:

- Review `utils/claude-with-docker.jsonc` and expand the relevant `filesystem.allow` list.
- The `post-start.sh` script pre-creates `~/.docker`, `$NONO_SANDBOX_DIR`, and `$NONO_SANDBOX_TMPDIR`
  so nono can apply policy to them. If those directories are missing (e.g. after a partial setup),
  recreate them:

```sh
mkdir -p ~/.docker "$NONO_SANDBOX_DIR" "$NONO_SANDBOX_TMPDIR"
```

### DinD: container fails to start

Docker-in-Docker requires `--privileged`. If your Docker host disallows privileged containers,
use the [sysbox](https://github.com/nestybox/sysbox) runtime — it provides equivalent isolation
without `--privileged`.

## Resources

- [Using Docker-in-Docker for your CI or testing environment? Think twice.](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/)
- [CI/CD Security Mistake: Are You Giving Your Build Container Root Access to Your Server?](https://dev.to/it-wibrc/cicd-security-mistake-are-you-giving-your-build-container-root-access-to-your-server-2jnm)
