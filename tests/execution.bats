#!/usr/bin/env bats
load helpers/setup

@test "soft failure is reported and subsequent code runs" {
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; initialize_action_registry; run_soft_step 2 false; printf continued'
  [ "$status" -eq 0 ]
  [[ $output == *failed* && $output == *continued* ]]
}

@test "hard failure aborts without running subsequent code" {
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; initialize_action_registry; run_step 2 false; touch "$HOME/continued"'
  [ "$status" -eq 1 ]
  [[ $output == *FATAL* ]]
  [ ! -e "$HOME/continued" ]
}

@test "privileged failure uses only sudo mock and aborts" {
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; initialize_action_registry; privileged_run_step 2 bashrc_resync.sh; touch "$HOME/continued"'
  [ "$status" -eq 1 ]
  assert_called sudo
  assert_not_called bashrc_resync.sh
  [ ! -e "$HOME/continued" ]
}
