#!/usr/bin/env bats
load helpers/setup

@test "help works without account configuration" {
  run "$TEST_BASH" "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ $output == *Usage:* && $output == *--run* ]]
  assert_not_called brew
}

@test "list exposes 33 numeric actions without handler internals" {
  run "$TEST_BASH" "$SCRIPT" --list
  [ "$status" -eq 0 ]
  [[ $output == *'Available actions:'* && $output != *action_bashrc_compare* ]]
  [ "$(printf '%s\n' "$output" | grep -Ec '^ *[0-9]+  - ')" -eq 33 ]
  assert_not_called clear
}

@test "run 2 parses noninteractive and dispatches the real handler to a mock" {
  write_admin_env
  make_mock bashrc_resync.sh <<< 'printf "comparison mock\n"'
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; initialize_action_registry; parse_args --run 2; [[ $MODE == run && $CHOICE == 2 && $NON_INTERACTIVE == 1 ]]'
  [ "$status" -eq 0 ]
  run "$TEST_BASH" "$SCRIPT" --run 2
  [ "$status" -eq 0 ]
  assert_called bashrc_resync.sh
  assert_not_called clear
}

@test "unknown numeric, nonnumeric and missing run IDs fail without dispatch" {
  local id
  for id in 9999 foo ''; do
    if [[ -n $id ]]; then run "$TEST_BASH" "$SCRIPT" --run "$id"
    else run "$TEST_BASH" "$SCRIPT" --run; fi
    [ "$status" -ne 0 ]
    [[ $output == *FATAL* ]]
  done
  assert_not_called bashrc_resync.sh
}

@test "unknown options are rejected before startup" {
  run "$TEST_BASH" "$SCRIPT" --unknown
  [ "$status" -ne 0 ]
  assert_not_called uname
  assert_not_called bashrc_resync.sh
}

@test "excess arguments and removed verbose list fail cleanly" {
  run "$TEST_BASH" "$SCRIPT" --run 2 3
  [ "$status" -ne 0 ]
  run "$TEST_BASH" "$SCRIPT" --list --verbose
  [ "$status" -ne 0 ]
  assert_not_called bashrc_resync.sh
}

@test "registry audit passes and catches duplicate, missing and orphan metadata" {
  run "$TEST_BASH" "$SCRIPT" --debug-choices
  [ "$status" -eq 0 ]
  [[ $output == *'Handlers validated: 33'* ]]
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; initialize_action_registry; ACTION_IDS+=(2); unset "ACTION_LABEL[3]"; ACTION_HANDLER[4]=absent_handler; ACTION_CATEGORY[900]=orphan; debug_validate_choice_map'
  [ "$status" -ne 0 ]
  [[ $output == *Duplicate* && $output == *'missing ACTION_LABEL'* && $output == *'not defined'* && $output == *Orphaned* ]]
}
