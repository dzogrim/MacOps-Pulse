#!/usr/bin/env bats
load helpers/setup
load helpers/compat

@test "native selector timeout 124 is retained and main executes zero handlers" {
  write_admin_env
  mock_selectors
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export SELECTOR_STATUS=124 SELECTOR_OUTPUT=$'2\tdefault focus'
  run_function select_action_fzf
  [ "$status" -eq 124 ]
  [ -z "$output" ]
  run_function select_action_gum
  [ "$status" -eq 124 ]
  [ -z "$output" ]
  check_unsuccessful_menus 0
}

@test "selector cancellation 130 is retained and main executes zero handlers" {
  write_admin_env
  mock_selectors
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export SELECTOR_STATUS=130 SELECTOR_OUTPUT=$'2\tdiscard this'
  run_function select_action_fzf
  [ "$status" -eq 130 ]
  run_function select_action_gum
  [ "$status" -eq 130 ]
  check_unsuccessful_menus 0
}

@test "arbitrary selector failures never accept accompanying action output" {
  write_admin_env
  mock_selectors
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export SELECTOR_STATUS=42 SELECTOR_OUTPUT=$'2\tdiscard this'
  run_function select_action_fzf
  [ "$status" -eq 42 ]
  run_function select_action_gum
  [ "$status" -eq 130 ]
  run_traced_cli --fzf
  [ "$status" -eq 1 ]
  assert_zero_actions
  run_traced_cli --gum
  [ "$status" -eq 0 ]
  assert_zero_actions
  assert_not_called sudo
}

@test "successful selectors with empty output cancel without dispatch" {
  write_admin_env
  mock_selectors
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export SELECTOR_STATUS=0 SELECTOR_OUTPUT=''
  check_unsuccessful_menus 0
}

@test "nonnumeric selector identity is fatal without dispatch" {
  write_admin_env
  mock_selectors
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export SELECTOR_STATUS=0 SELECTOR_OUTPUT=$'oops\tvisible [02]'
  check_unsuccessful_menus 1
}

@test "unregistered numeric selector identity fails without dispatch" {
  write_admin_env
  mock_selectors
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export SELECTOR_STATUS=0 SELECTOR_OUTPUT=$'9999\tvisible [02]'
  run_traced_cli --fzf
  [ "$status" -eq 1 ]
  assert_zero_actions
  SELECTOR_OUTPUT=9999
  run_traced_cli --gum
  [ "$status" -eq 1 ]
  assert_zero_actions
}

@test "fzf output without a structured delimiter is rejected" {
  write_admin_env
  mock_selectors
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export SELECTOR_STATUS=0 SELECTOR_OUTPUT=2
  run_traced_cli --fzf
  [ "$status" -eq 1 ]
  assert_zero_actions
}

@test "gum absence falls back to fzf and cancellation never falls back to an action" {
  write_admin_env
  mock_selectors
  remove_mock gum
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export SELECTOR_STATUS=130
  run_traced_cli --gum
  [ "$status" -eq 0 ]
  [[ $output == *'Falling back to fzf'* ]]
  assert_called fzf
  assert_zero_actions
  assert_not_called sudo
}

@test "explicit missing fzf fails before clearing even when gum is available" {
  write_admin_env
  mock_selectors
  remove_mock fzf
  run_traced_cli --fzf
  [ "$status" -eq 1 ]
  [[ $output == *'missing tools:'* && $output == *fzf* ]]
  assert_not_called gum
  assert_not_called clear
  assert_zero_actions
  remove_mock gum
  run_traced_cli --gum
  [ "$status" -eq 1 ]
  assert_not_called clear
  assert_zero_actions
}
