# `gh` command sandbox (+ `git` via `git.from.gh`)

if ! timeout "$TIMEOUT" gh auth status >/dev/null 2>&1; then
  group "gh"
  skip "gh checks" "not logged in (run \`gh auth login\` outside the sandbox)"
  return 0
fi

BLOCKED="blocked by nono profile"

group "gh: allowed"
expect_ok_match "auth status"                "Logged in to"      gh auth status
# `owner/name` from the remote url (`git@github.com:o/n.git`, `https://github.com/o/n.git`, ...)
NWO=$(printf '%s' "$REMOTE_URL" | sed -E 's#^.*github\.com[:/]##; s#\.git$##')
expect_ok "pr list (--repo, no git)"         gh pr list --repo "$NWO" --limit 1

group "gh: gh -> git"
# no `--repo`, so gh resolves the repo/branch by running git in the cwd
expect_ok "repo view (repo from git remote)" bash -c 'cd "$1" && gh repo view --json name' _ "$REPO"
expect_ok "pr status (branch from git)"      bash -c 'cd "$1" && gh pr status' _ "$REPO"

group "gh: blocked (token leaks / misuse)"
expect_denied "auth token"                   "$BLOCKED" gh auth token
expect_denied "auth status -t"               "$BLOCKED" gh auth status -t
expect_denied "auth status --show-token"     "$BLOCKED" gh auth status --show-token
expect_denied "auth git-credential"          "$BLOCKED" gh auth git-credential get
expect_denied "auth login"                   "$BLOCKED" gh auth login
expect_denied "config get oauth_token"       "$BLOCKED" gh config get oauth_token
expect_denied "config set"                   "$BLOCKED" gh config set editor vim
expect_denied "extension list"               "$BLOCKED" gh extension list
expect_denied "ext list (alias)"             "$BLOCKED" gh ext list
