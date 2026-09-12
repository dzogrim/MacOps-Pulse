#!/usr/bin/env bats
load helpers/setup
load helpers/compat

@test "empty HOME is rejected by isolation guard and execution never falls back to an account home" {
  run /usr/bin/env HOME= "$TEST_BASH" "$TEST_ROOT/suite/tests/helpers/invoke.bash" initialize_execution_environment
  [ "$status" -eq 90 ]
  # Run main separately inside the OS sandbox: its required env file cannot resolve.
  # The path assertion above prevents mocks from accepting this invalid home.
  run /usr/bin/env HOME= "$TEST_BASH" "$SCRIPT" --run 2
  [ "$status" -eq 1 ]
  [[ $output == *'AdminHelpers environment is missing'* ]]
  assert_not_called bashrc_resync.sh
  assert_not_called sudo
}

@test "empty USER and TMPDIR cannot redirect a direct comparison away from synthetic HOME" {
  write_admin_env
  make_mock bashrc_resync.sh <<'MOCK'
[[ $HOME == "$CASE_ROOT/home" && -z $USER && -z $TMPDIR ]] || exit 88
MOCK
  run /usr/bin/env USER= TMPDIR= "$TEST_BASH" "$SCRIPT" --run 2
  [ "$status" -eq 0 ]
  assert_called bashrc_resync.sh
  assert_not_called sudo
}

@test "synthetic HOME and executable PATH with spaces and Unicode remain usable" {
  local unusual="$CASE_ROOT/maison été [1]"
  mkdir -p "$unusual" "$CASE_ROOT/outils été"
  ln -s "$TEST_BASH" "$CASE_ROOT/outils été/bash"
  run /usr/bin/env HOME="$unusual" PATH="$CASE_ROOT/outils été:/usr/bin:/bin" "$TEST_BASH" "$SCRIPT" --list
  [ "$status" -eq 0 ]
  [[ $output == *'Available actions:'* ]]
  [ ! -e "$unusual/.config" ]
}

@test "destructive mock helpers reject empty traversal and outside paths before mutation" {
  printf keep > "$HOME/keep"
  local path
  for path in '' /outside-fixture "$HOME/../keep" "$TEST_ROOT" "$HOME/"$'newline\n/../../escape'; do
    run rm -rf -- "$path"
    [ "$status" -eq 90 ]
    run mv -- "$HOME/keep" "$path"
    [ "$status" -eq 90 ]
    [ "$(cat "$HOME/keep")" = keep ]
  done
}

@test "internal symlinks resolving outside the sandbox are rejected before destructive operations" {
  ln -s /outside-fixture "$HOME/escape"
  ln -s "$HOME/escape" "$HOME/chain"
  printf keep > "$HOME/keep"
  local path
  for path in "$HOME/escape" "$HOME/escape/child" "$HOME/chain/child"; do
    run rm -rf -- "$path"
    [ "$status" -eq 90 ]
    run mv -- "$HOME/keep" "$path"
    [ "$status" -eq 90 ]
    [ "$(cat "$HOME/keep")" = keep ]
  done
  [ -L "$HOME/escape" ]
}
