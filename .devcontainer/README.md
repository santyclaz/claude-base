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

| Variable        | Default               | Effect                                                                                                                                                                                                     |
| --------------- | --------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `TZ`            | `America/Los_Angeles` | Container timezone.                                                                                                                                                                                        |
| `BUILD_SCRIPTS` | _(empty)_             | Space-separated list of installers from `build-scripts/` to run during image build (`.sh` suffix optional). Available: `install-bun`, `install-node`. Example: `BUILD_SCRIPTS="install-bun install-node"`. |

> **Claude config persistence** is handled via a named Docker volume
> mounted at `/home/eng-user/.claude`. This volume survives container rebuilds but is lost if
> explicitly pruned. `CLAUDE_CONFIG_DIR` is set to that path inside the container as a workaround
> for an [OAuth callback bug](https://github.com/anthropics/claude-code/issues/1736#issuecomment-3113994138).

## nono security sandbox

Claude Code runs wrapped in [nono](https://nono.sh/), which enforces filesystem and network
policies at runtime. The `claude` command is aliased to:

```sh
NONO_COMPOSE_TMPDIR=/tmp/nono-compose/ nono run --allow /workspace/ --allow /tmp/nono-compose/ --allow ~/.nono-bin/ --profile claude-with-docker -- claude
```

- **`/workspace/`** — read+write access to your project files.
- **`/tmp/nono-compose/`** — read+write scratch space used by the `docker compose` TMPDIR shim (see below).
- **`~/.nono-bin/`** — read+write access to the passthrough `docker` binary shim.
- **`claude-with-docker` profile** — extends the built-in `claude-code` nono pack with additional
  access needed for Docker operations (`$HOME/.docker`, Docker CLI plugin paths). The profile lives
  at `utils/claude-with-docker.jsonc`; edit it to adjust what Claude Code can access. Note that the
  profile explicitly **denies** `/vscode/vscode-server/bin` to prevent the VS Code IDE integration
  from running outside the sandbox.

> The `anthropic.claude-code` VS Code extension is intentionally **not** installed — it would run
> Claude Code outside the nono sandbox. Use the `claude` CLI instead.

### docker compose TMPDIR shim

`docker compose` writes temporary files to `/tmp` by default
([upstream issue](https://github.com/docker/compose/issues/4137)), which nono blocks. To work
around this, a passthrough `docker` binary is placed at `~/.nono-bin/docker` (ahead of
`/usr/bin/docker` on `PATH`). When invoked as `docker compose`, it re-executes the real Docker CLI
with `TMPDIR` set to `$NONO_COMPOSE_TMPDIR` (`/tmp/nono-compose/`), which is an allowed path. All
other `docker` subcommands pass through unchanged.

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
- The `post-create.sh` script pre-creates `~/.docker`, `/tmp/claude-$UID`, and `/tmp/nono-compose`
  so nono can apply policy to them. If those directories are missing (e.g. after a partial setup),
  recreate them:

```sh
mkdir -p ~/.docker /tmp/claude-$UID /tmp/nono-compose
```

### DinD: container fails to start

Docker-in-Docker requires `--privileged`. If your Docker host disallows privileged containers,
use the [sysbox](https://github.com/nestybox/sysbox) runtime — it provides equivalent isolation
without `--privileged`.

## Resources

- [Using Docker-in-Docker for your CI or testing environment? Think twice.](https://jpetazzo.github.io/2015/09/03/do-not-use-docker-in-docker-for-ci/)
- [CI/CD Security Mistake: Are You Giving Your Build Container Root Access to Your Server?](https://dev.to/it-wibrc/cicd-security-mistake-are-you-giving-your-build-container-root-access-to-your-server-2jnm)
