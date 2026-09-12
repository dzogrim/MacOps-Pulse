#!/usr/bin/env bats
load helpers/setup

@test "sandbox paths reject escapes and symlink traversal" {
  assert_sandbox_path "$HOME/Desktop"
  assert_sandbox_path "$TMPDIR"
  run ! assert_sandbox_path ""
  run ! assert_sandbox_path /
  run ! assert_sandbox_path "$TEST_ROOT"
  run ! assert_sandbox_path "$HOME/../escape"
  ln -s /outside-fixture "$HOME/link"
  run ! assert_sandbox_path "$HOME/link/child"
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c '[[ ! -r /etc/passwd ]]'
  [ "$status" -eq 0 ]
  run ! /usr/bin/sudo -n true
  [[ $output == *'Operation not permitted'* ]]
}

@test "sourcing is inert and retains production timeout and focus defaults" {
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; [[ $TIMEOUT_SEC == 50 && $DEFAULT_SELECTION == 2 ]] || exit 1; declare -F dispatch_action || exit 1; [[ ! -e "$ADMIN_HELPERS_ENV" ]]'
  [ "$status" -eq 0 ]
  assert_not_called sudo
  assert_not_called clear
  assert_not_called brew
}
