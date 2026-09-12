#!/usr/bin/env bats
load helpers/setup

@test "fzf deadline exits main cleanly without default dispatch or a lingering selector" {
  write_admin_env
  # Each Bats case has its own child environment.
  # shellcheck disable=SC2030,SC2031
  export TIMEOUT_SEC
  # The override is deliberately local to this test.
  # shellcheck disable=SC2030,SC2031
  TIMEOUT_SEC=1
  make_mock fzf <<'MOCK'
printf '%s\n' "$$" > "$HOME/selector.pid"
# Replace the mock process, avoiding an extra sleeper child.
exec /bin/sleep 20
MOCK
  run "$TEST_BASH" "$SCRIPT" --fzf
  [ "$status" -eq 0 ]
  [[ $output == *'timed out after 1 seconds'* ]]
  local selector_pid
  read -r selector_pid < "$HOME/selector.pid"
  run ! kill -0 "$selector_pid" 2>/dev/null
  assert_not_called bashrc_resync.sh
  assert_called clear
}

@test "gum native timeout discards even a default ID printed on expiry" {
  write_admin_env
  # Each Bats case has its own child environment.
  # shellcheck disable=SC2030,SC2031
  export TIMEOUT_SEC
  # The override is deliberately local to this test.
  # shellcheck disable=SC2030,SC2031
  TIMEOUT_SEC=1
  make_mock gum <<'MOCK'
/bin/sleep 0.05
printf '2\n'
exit 124
MOCK
  run "$TEST_BASH" "$SCRIPT" --gum
  [ "$status" -eq 0 ]
  [[ $output == *'timed out after 1 seconds'* ]]
  [[ $(cat "$MOCK_LOG_DIR/gum") == *--timeout=1s* ]]
  assert_not_called bashrc_resync.sh
}

@test "both selectors preserve structured ID selection and default focus flags" {
  make_mock fzf <<'MOCK'
found=0
for arg in "$@"; do [[ $arg != '--bind=load:pos(2)' ]] || found=1; done
[[ $found == 1 ]] || exit 88
cat >/dev/null
printf '17\tmisleading visible [02] label\n' 
MOCK
  run_function select_action_fzf
  [ "$status" -eq 0 ]
  [ "$output" = 17 ]
  [[ $(cat "$MOCK_LOG_DIR/fzf") == *'load:pos'* && $(cat "$MOCK_LOG_DIR/fzf") == *'2'* ]]
  make_mock gum <<'MOCK'
selected='' expected=''
for arg in "$@"; do
  case $arg in
    --selected=*) selected=${arg#--selected=} ;;
    *$'\t2') expected=${arg%$'\t2'} ;;
  esac
done
[[ -n $expected && $selected == "$expected" ]] || exit 88
printf '17\n' 
MOCK
  run_function select_action_gum
  [ "$status" -eq 0 ]
  [ "$output" = 17 ]
  [[ $(cat "$MOCK_LOG_DIR/gum") == *--selected=* && $(cat "$MOCK_LOG_DIR/gum") == *'02'* && $(cat "$MOCK_LOG_DIR/gum") == *--timeout=50s* ]]
}

@test "selector cancellation exits main without dispatch" {
  write_admin_env
  make_mock fzf <<< 'exit 130'
  make_mock gum <<< 'exit 130'
  local flag
  for flag in --fzf --gum; do
    run "$TEST_BASH" "$SCRIPT" "$flag"
    [ "$status" -eq 0 ]
    [[ $output == *'User aborted'* ]]
  done
  assert_not_called bashrc_resync.sh
}
