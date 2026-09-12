#!/usr/bin/env bats
load helpers/setup
load helpers/compat

@test "all metadata modes bypass AdminHelpers and the full execution environment" {
  local name flag
  for name in brew git mas mdutil jq; do remove_mock "$name"; done
  for flag in --help --list --debug-choices; do
    run_traced_cli "$flag"
    [ "$status" -eq 0 ]
    assert_zero_actions
    run ! grep -E 'TRACE:initialize_(execution|admin)_environment:' "$CASE_ROOT/trace"
  done
  assert_not_called uname
  assert_not_called sudo
}

@test "direct run enters only its selected action once with no selector or sudo" {
  write_admin_env
  make_mock bashrc_resync.sh <<< 'exit 0'
  mock_selectors
  run_traced_cli --run 2
  [ "$status" -eq 0 ]
  [ "$(grep -c 'TRACE:dispatch_action: action_bashrc_compare 2$' "$CASE_ROOT/trace")" -eq 1 ]
  [ "$(grep -oE 'TRACE:action_[a-z_]+:' "$CASE_ROOT/trace" | sort -u)" = 'TRACE:action_bashrc_compare:' ]
  [ "$(wc -l < "$MOCK_LOG_DIR/bashrc_resync.sh")" -eq 1 ]
  assert_not_called gum
  assert_not_called fzf
  assert_not_called sudo
}

@test "conflicting menu flags and signed or whitespace IDs never enter handlers" {
  local arg
  for arg in -2 ' 2' '2 ' '2;echo unsafe'; do
    run_traced_cli --run "$arg"
    [ "$status" -ne 0 ]
    assert_zero_actions
  done
  run_traced_cli --gum --fzf
  [ "$status" -ne 0 ]
  assert_zero_actions
  assert_not_called uname
}

@test "source-only loading ignores synthetic profiles and environment initialization" {
  # Fixture code must expand HOME only if the child improperly sources it.
  # shellcheck disable=SC2016
  printf 'touch "$HOME/profile-ran"\n' > "$HOME/.bashrc"
  # shellcheck disable=SC2016
  printf 'touch "$HOME/admin-ran"\n' > "$HOME/.config/AdminHelpers/env"
  # Defer variable expansion to the isolated child.
  # shellcheck disable=SC2016
  run "$TEST_BASH" --noprofile --norc -c 'source "$SCRIPT" || exit 1; declare -F parse_args dispatch_action initialize_admin_environment; [[ $DEFAULT_SELECTION == 2 && ${#ACTION_IDS[@]} == 0 ]]'
  [ "$status" -eq 0 ]
  [ ! -e "$HOME/profile-ran" ]
  [ ! -e "$HOME/admin-ran" ]
  assert_not_called brew
  assert_not_called sudo
  assert_not_called uname
  assert_not_called bashrc_resync.sh
}

@test "unset empty and explicit timeout hooks retain defaults and initial-focus semantics" {
  run_probe <<'BASH'
[[ $TIMEOUT_SEC == 50 && $DEFAULT_SELECTION == 2 ]] || exit 1
parse_args
[[ $MODE == interactive && $MENU_ENGINE == fzf && $NON_INTERACTIVE == 0 && -z $CHOICE ]]
BASH
  [ "$status" -eq 0 ]
  # Expansion belongs to the child shell after source has defined the readonly value.
  # shellcheck disable=SC2016
  run /usr/bin/env TIMEOUT_SEC= "$TEST_BASH" -c 'source "$SCRIPT"; [[ $TIMEOUT_SEC == 50 ]]'
  [ "$status" -eq 0 ]
  # shellcheck disable=SC2016
  run /usr/bin/env TIMEOUT_SEC=1 "$TEST_BASH" -c 'source "$SCRIPT"; [[ $TIMEOUT_SEC == 1 && $DEFAULT_SELECTION == 2 ]]'
  [ "$status" -eq 0 ]
}
