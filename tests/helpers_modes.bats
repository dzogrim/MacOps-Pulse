#!/usr/bin/env bats
load helpers/setup

@test "helper modes reach their own checks without maintenance and protect absent Dropbox" {
  remove_mock brew
  remove_mock mas
  remove_mock mdutil
  run "$TEST_BASH" "$SCRIPT" --check-deps-scpt
  [ "$status" -ne 0 ]
  [[ $output == *'Missing:'* && $output != *FATAL* ]]
  assert_not_called uname
  write_admin_env
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  printf 'ADM_SHELL_SCPT_PERSO="$HOME/Library/CloudStorage/Dropbox/helpers"\n' >> "$HOME/.config/AdminHelpers/env"
  run "$TEST_BASH" "$SCRIPT" --install-deps-scpt
  [ "$status" -ne 0 ]
  [[ $output == *'Dropbox is unavailable'* ]]
  [ ! -e "$HOME/Library/CloudStorage/Dropbox" ]
  assert_not_called gh
  assert_not_called install
  assert_not_called clear
  assert_not_called uname
}
