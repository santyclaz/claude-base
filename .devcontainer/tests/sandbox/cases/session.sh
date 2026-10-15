# the session itself (no command sandbox involved) -- credentials and forwarded sockets are out of reach

group "session: credential dirs"
expect_denied "can't list ~/.ssh"           "Permission denied" ls ~/.ssh
expect_denied "can't read ~/.config/gh"     "Permission denied" cat ~/.config/gh/hosts.yml

group "session: ssh / agent"
expect_denied "direct ssh is denied"        "command policy denied ssh" ssh -T git@github.com
if [ -n "${SSH_AUTH_SOCK:-}" ]; then
  # `af_unix_mediation: pathname` -- the agent socket is only handed to the `ssh` command sandbox
  expect_denied "ssh agent unreachable"     "Error connecting to agent: Permission denied" ssh-add -l
else
  skip "ssh agent unreachable" "SSH_AUTH_SOCK not set"
fi

group "session: allowed sockets"
if [ -S /var/run/docker.sock ] && command -v docker >/dev/null; then
  expect_ok "docker daemon reachable"       docker version --format '{{.Server.Version}}'
else
  skip "docker daemon reachable" "no docker socket/cli"
fi
