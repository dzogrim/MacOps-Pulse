# Run a trusted heredoc against real definitions in a disposable child process.
run_probe() {
  assert_sandbox_path "$CASE_ROOT/probe.bash" || return 1
  {
    # Resolve SCRIPT inside the isolated child, not the generated probe.
    # shellcheck disable=SC2016
    printf 'source "$SCRIPT"\ninitialize_action_registry\n'
    cat
  } > "$CASE_ROOT/probe.bash"
  run "$TEST_BASH" --noprofile --norc "$CASE_ROOT/probe.bash"
}

# Trace function execution without replacing production handlers or the dispatcher.
run_traced_cli() {
  # Keep FUNCNAME expansion in the child; tracing captures executed code, not definitions.
  # shellcheck disable=SC2016
  run /usr/bin/env 'PS4=TRACE:${FUNCNAME[0]:-main}: ' BASH_XTRACEFD=9 \
    "$TEST_BASH" --noprofile --norc -x "$SCRIPT" "$@" 9>"$CASE_ROOT/trace"
}

# Reject any executed action-handler frame in the real CLI trace.
assert_zero_actions() {
  if grep -Eq 'TRACE:action_[a-z_]+:' "$CASE_ROOT/trace"; then
    printf 'Unexpected action handler in CLI trace\n' >&2
    return 1
  fi
}

# Give a single child an explicit PATH with only named fixture/system utilities.
make_minimal_path() {
  mkdir -p "$CASE_ROOT/minimal"
  local name origin
  for name in bash cat basename stty "$@"; do
    origin="$CASE_ROOT/bin/$name"
    [[ -e $origin ]] || origin="/usr/bin/$name"
    [[ -e $origin ]] || origin="/bin/$name"
    [[ -e $origin ]] || return 1
    [[ -e "$CASE_ROOT/minimal/$name" ]] || ln -s "$origin" "$CASE_ROOT/minimal/$name"
  done
}

# Emit selector output/status deterministically; input is drained to avoid pipe races.
mock_selectors() {
  make_mock fzf <<'MOCK'
cat >/dev/null
[[ -z ${SELECTOR_OUTPUT:-} ]] || printf '%s\n' "$SELECTOR_OUTPUT"
exit "${SELECTOR_STATUS:-0}"
MOCK
  make_mock gum <<'MOCK'
[[ -z ${SELECTOR_OUTPUT:-} ]] || printf '%s\n' "$SELECTOR_OUTPUT"
exit "${SELECTOR_STATUS:-0}"
MOCK
}

# Assert both selector CLIs terminate without entering any action handler.
check_unsuccessful_menus() {
  local flag
  for flag in --fzf --gum; do
    run_traced_cli "$flag"
    # Bats run assigns status in this calling shell.
    # shellcheck disable=SC2154
    [ "$status" -eq "$1" ] || return 1
    assert_zero_actions || return 1
    assert_not_called sudo || return 1
  done
}

# Journal external batch steps, with optional failures chosen by command name.
mock_batch_commands() {
  local name
  for name in "$@"; do
    make_mock "$name" <<'MOCK'
name=${0##*/}
printf '%s\n' "$name" >> "$HOME/batch-order"
[[ ${FAIL_STEP:-} != "$name" ]]
MOCK
  done
}
