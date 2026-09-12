#!/usr/bin/env bats
load helpers/setup

@test "empty account name is rejected with its configuration key" {
  run_function validate_local_account '' ADM_SHELL_USER_PERSO
  [ "$status" -ne 0 ]
  [[ $output == *ADM_SHELL_USER_PERSO* ]]
}

@test "both required account variables reject unset and empty values" {
  local key value
  for key in ADM_SHELL_USER_PERSO ADM_SHELL_USER_PROv1; do
    for value in unset empty; do
      write_admin_env
      if [[ $value == unset ]]; then printf 'unset %s\n' "$key" >> "$HOME/.config/AdminHelpers/env"
      else printf '%s=\n' "$key" >> "$HOME/.config/AdminHelpers/env"; fi
      run_function initialize_admin_environment
      [ "$status" -ne 0 ]
      [[ $output == *"$key"* ]]
    done
  done
}

@test "configured account mapping works and unknown installation account fails" {
  write_admin_env
  run_function validate_local_account fixture-home fixture-key
  [ "$status" -eq 0 ]
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; initialize_admin_environment; resolve_script_install_dir'
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/helpers" ]
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; initialize_admin_environment; LOGNAME=unknown; resolve_script_install_dir'
  [ "$status" -ne 0 ]
  [[ $output == *'unsupported account'* ]]
}

@test "missing AdminHelpers environment blocks initialization" {
  run_function initialize_execution_environment
  [ "$status" -ne 0 ]
  [[ $output == *'missing or unreadable'* ]]
  assert_not_called uname
}

@test "mocked nonmacOS is rejected before maintenance commands" {
  write_admin_env
  make_mock uname <<< 'printf "Linux\n"'
  run_function initialize_execution_environment
  [ "$status" -ne 0 ]
  [[ $output == *'macOS only'* ]]
  assert_not_called brew
}
