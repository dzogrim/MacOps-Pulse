# Write one deterministic executable and record shell-escaped arguments per command.
# Generated mock variables must expand only when the mock runs.
# shellcheck disable=SC2016
make_mock() {
  local name=$1 destination="$CASE_ROOT/bin/$1"
  [[ "$name" =~ ^[a-zA-Z0-9_.-]+$ ]] || return 1
  assert_sandbox_path "$destination" || return 1
  {
    printf '#!/usr/bin/env bash\n'
    printf 'source "$TEST_ROOT/suite/tests/helpers/safety.bash"\n'
    printf 'require_isolation || exit 90\n'
    printf 'printf "%%q " "$@" >> "$MOCK_LOG_DIR/%s"\n' "$name"
    printf 'printf "\\n" >> "$MOCK_LOG_DIR/%s"\n' "$name"
    cat
  } > "$destination"
  chmod +x "$destination"
}

# Check that the named command was invoked at least once.
assert_called() { [[ -s "$MOCK_LOG_DIR/$1" ]]; }

# Check that the named command was never invoked.
assert_not_called() { [[ ! -e "$MOCK_LOG_DIR/$1" ]]; }

# Remove only a validated mock entry, without following symlink targets.
remove_mock() {
  [[ $1 =~ ^[a-zA-Z0-9_.-]+$ ]] || return 1
  assert_sandbox_path "$CASE_ROOT/bin" || return 1
  /bin/rm -f -- "$CASE_ROOT/bin/$1"
}
