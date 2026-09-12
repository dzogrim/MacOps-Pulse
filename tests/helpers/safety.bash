# Bats uses TEST_ROOT internally; restore our launcher-owned root in test children.
export TEST_ROOT="${REFRESH_TEST_ROOT:-}"

# Reject unsafe paths lexically and reject symlink traversal without following it.
assert_sandbox_path() {
  local path=${1:-} current=$TEST_ROOT part
  # read consumes one line; reject line breaks before splitting path components.
  [[ -n "$path" && "$path" == "$TEST_ROOT/"* && "$path" != *'//'* &&
     "$path" != *$'\n'* && "$path" != *$'\r'* ]] || return 1
  local relative=${path#"$TEST_ROOT/"}
  local -a parts
  IFS=/ read -r -a parts <<< "$relative"
  for part in "${parts[@]}"; do
    [[ -n "$part" && "$part" != . && "$part" != .. ]] || return 1
    current+="/$part"
    [[ ! -L "$current" ]] || return 1
  done
}

# Fail before fixtures or production code can run outside the isolated launcher.
require_isolation() {
  [[ ${REFRESH_TEST_ISOLATED:-} == 1 && ${TEST_ROOT:-} == /private/tmp/refresh-tests-* &&
     -f "$TEST_ROOT/.isolated-suite" && ${HOME:-} == "$TEST_ROOT/"* ]] || {
    printf 'Use tests/run: isolated launcher required.\n' >&2
    return 1
  }
  assert_sandbox_path "$HOME"
}
