# `git` command sandbox (+ `ssh` via `ssh.from.git`)

group "git: local"
expect_ok "rev-parse in /workspace repo"     git -C "$REPO" rev-parse HEAD
expect_ok "status in /workspace repo"        git -C "$REPO" status --porcelain

# throwaway repo under the sandbox tmp dir (`/tmp/nono-sandbox` grant)
T="$SCRATCH/repo"
G=(git -C "$T" -c user.name=sandbox-test -c user.email=sandbox-test@example.invalid -c commit.gpgsign=false)
expect_ok "init repo in sandbox tmp dir"     git init -q "$T"
echo one > "$T/f"
expect_ok "add + commit (-m)"                bash -c '"$@" add f && "$@" commit -qm one' _ "${G[@]}"

# piped stdin reaches mediated git (follow-up #3)
echo two >> "$T/f"
STDIN=$(git -C "$T" diff) expect_ok "apply --cached - (stdin)" "${G[@]}" apply --cached -
STDIN="msg from stdin" expect_ok "commit -F - (stdin)" "${G[@]}" commit -q -F -
expect_ok_match "stdin commit message landed" "^msg from stdin$" git -C "$T" log -1 --format=%s

# files in the sandbox tmp dir, e.g. claude's scratchpad (follow-up #2)
echo three >> "$T/f"
git -C "$T" diff > "$SCRATCH/p.patch"
echo "msg from file" > "$SCRATCH/msg"
expect_ok "apply --cached <tmp file>"        "${G[@]}" apply --cached "$SCRATCH/p.patch"
expect_ok "commit -F <tmp file>"             "${G[@]}" commit -q -F "$SCRATCH/msg"

group "git: remotes"
expect_ok "https ls-remote (public repo)"    git ls-remote https://github.com/git/git.git HEAD
if [[ $REMOTE_URL != git@* && $REMOTE_URL != ssh://* ]]; then
  skip "ssh remote checks" "$REMOTE is not an ssh remote"
elif [ -z "${SSH_AUTH_SOCK:-}" ]; then
  skip "ssh remote checks" "SSH_AUTH_SOCK not set"
else
  expect_ok "ssh ls-remote ($REMOTE)"        git -C "$REPO" ls-remote "$REMOTE" HEAD
  expect_ok "ssh fetch --dry-run ($REMOTE)"  git -C "$REPO" fetch --dry-run "$REMOTE"
  if [ "$WITH_WRITES" -eq 1 ]; then
    ref="sandbox-test-$(date +%s)"
    expect_ok "ssh push throwaway branch"    git -C "$REPO" push -q "$REMOTE" "HEAD:refs/heads/$ref"
    expect_ok "ssh delete throwaway branch"  git -C "$REPO" push -q "$REMOTE" --delete "$ref"
  fi
fi
