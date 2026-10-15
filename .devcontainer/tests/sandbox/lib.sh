# Test helpers for `run.sh` -- sourced, not executed
#
# Every check captures stdout+stderr, so a denial is asserted by its *reason* (e.g. nono's policy message,
# `Permission denied`), not just a non-zero exit -- otherwise a network flake or typo would also "pass"

PASS=0 FAIL=0 SKIP=0
FAILED=()
TIMEOUT=${TIMEOUT:-60}

if [ -t 1 ]; then
  C_PASS=$'\e[32m' C_FAIL=$'\e[31m' C_SKIP=$'\e[33m' C_DIM=$'\e[2m' C_HEAD=$'\e[1;36m' C_OFF=$'\e[0m'
else
  C_PASS= C_FAIL= C_SKIP= C_DIM= C_HEAD= C_OFF=
fi

# secrets that must never show up in output (also used to redact failure output before printing it)
# - github tokens (`gho_`, `ghp_`, `ghu_`, `ghs_`, `ghr_`, `github_pat_`)
# - JWTs (e.g. cloud provider access tokens)
# - ssh agent key listings (`ssh-add -l`)
SECRET_RE='(gh[oprsu]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}|SHA256:[A-Za-z0-9+/]{43})'

redact() { sed -E "s#${SECRET_RE}#<REDACTED>#g"; }

group() { printf '\n%s== %s ==%s\n' "$C_HEAD" "$1" "$C_OFF"; }

_pass() { PASS=$((PASS + 1)); printf '  %sPASS%s %s\n' "$C_PASS" "$C_OFF" "$1"; }
_skip() { SKIP=$((SKIP + 1)); printf '  %sSKIP%s %s %s(%s)%s\n' "$C_SKIP" "$C_OFF" "$1" "$C_DIM" "$2" "$C_OFF"; }
_fail() {
  FAIL=$((FAIL + 1)); FAILED+=("$1")
  printf '  %sFAIL%s %s -- %s\n' "$C_FAIL" "$C_OFF" "$1" "$2"
  printf '%s\n' "$OUT" | redact | tail -n 15 | sed "s/^/       ${C_DIM}|${C_OFF} /"
  [ -n "$C_DIM" ] && printf '%s' "$C_OFF"
}

# _run <cmd...> -- sets OUT (stdout+stderr) and RC. stdin is /dev/null unless `STDIN` is set
_run() {
  if [ -n "${STDIN+x}" ]; then
    OUT=$(printf '%s\n' "$STDIN" | timeout "$TIMEOUT" "$@" 2>&1)
  else
    OUT=$(timeout "$TIMEOUT" "$@" 2>&1 </dev/null)
  fi
  RC=$?
}

# fails the check if a secret leaked into the output, regardless of exit code
_leaked() { printf '%s' "$OUT" | grep -qE "$SECRET_RE"; }

# expect_ok <name> <cmd...> -- command succeeds and leaks no secrets
expect_ok() {
  local name=$1; shift
  _run "$@"
  if _leaked; then _fail "$name" "secret in output"
  elif [ "$RC" -eq 124 ]; then _fail "$name" "timed out after ${TIMEOUT}s"
  elif [ "$RC" -ne 0 ]; then _fail "$name" "exit $RC"
  else _pass "$name"
  fi
}

# expect_ok_match <name> <regex> <cmd...> -- command succeeds and output matches <regex> (ERE)
expect_ok_match() {
  local name=$1 re=$2; shift 2
  _run "$@"
  if _leaked; then _fail "$name" "secret in output"
  elif [ "$RC" -ne 0 ]; then _fail "$name" "exit $RC"
  elif ! printf '%s' "$OUT" | grep -qE -- "$re"; then _fail "$name" "output didn't match /$re/"
  else _pass "$name"
  fi
}

# expect_denied <name> <regex> <cmd...> -- output matches <regex> (ERE) and leaks no secrets. The exit code
# isn't checked since nono `intercept` responses exit 0
expect_denied() {
  local name=$1 re=$2; shift 2
  _run "$@"
  if _leaked; then _fail "$name" "secret in output"
  elif [ "$RC" -eq 124 ]; then _fail "$name" "timed out after ${TIMEOUT}s"
  elif ! printf '%s' "$OUT" | grep -qE -- "$re"; then _fail "$name" "expected denial matching /$re/ (exit $RC)"
  else _pass "$name"
  fi
}

skip() { _skip "$1" "$2"; }

# logged_in <tool> -- per `SANDBOX_TESTS_LOGGED_IN`, set by `run.sh` outside the sandbox. Unset (in-session
# runs) counts as logged in, so a broken sandbox fails instead of being skipped
logged_in() { [ -z "${SANDBOX_TESTS_LOGGED_IN+x}" ] || [[ " $SANDBOX_TESTS_LOGGED_IN " == *" $1 "* ]]; }

summary() {
  printf '\n%s passed, %s failed, %s skipped\n' "$PASS" "$FAIL" "$SKIP"
  if [ "$FAIL" -gt 0 ]; then
    printf '%sfailed:%s\n' "$C_FAIL" "$C_OFF"
    printf '  - %s\n' "${FAILED[@]}"
    return 1
  fi
}
