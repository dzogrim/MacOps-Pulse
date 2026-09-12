#!/usr/bin/env bats
load helpers/setup

@test "valid JSON resolves an existing string path through jq" {
  write_dropbox
  run_function get_dropbox_path
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/Dropbox Fixture" ]
}

@test "malformed Dropbox JSON fails without fabricating the standard root" {
  mkdir -p "$HOME/Library/Application Support/Dropbox"
  cp "$TEST_ROOT/suite/tests/fixtures/dropbox/invalid.json" "$HOME/Library/Application Support/Dropbox/info.json"
  run_function get_dropbox_path
  [ "$status" -ne 0 ]
  [ ! -e "$HOME/Library/CloudStorage/Dropbox" ]
}

@test "missing, empty, numeric, object, array and relative Dropbox paths fail" {
  mkdir -p "$HOME/Library/Application Support/Dropbox"
  local json
  for json in '{}' '{"personal":{"path":""}}' '{"personal":{"path":7}}' '{"personal":{"path":{}}}' '{"personal":{"path":[]}}' '{"personal":{"path":"relative"}}'; do
    printf '%s\n' "$json" > "$HOME/Library/Application Support/Dropbox/info.json"
    run_function get_dropbox_path
    [ "$status" -ne 0 ]
    [ -z "$output" ]
  done
}

@test "legacy no-jq extraction still validates the candidate directory" {
  write_dropbox
  remove_mock jq
  # Newer macOS also ships jq in /usr/bin; give this child a genuinely jq-free PATH.
  local tool
  for tool in grep sed head; do ln -s "/usr/bin/$tool" "$CASE_ROOT/bin/$tool"; done
  run /usr/bin/env PATH="$CASE_ROOT/bin" "$TEST_BASH" "$TEST_ROOT/suite/tests/helpers/invoke.bash" get_dropbox_path
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/Dropbox Fixture" ]
  mv "$HOME/Dropbox Fixture" "$HOME/renamed"
  run /usr/bin/env PATH="$CASE_ROOT/bin" "$TEST_BASH" "$TEST_ROOT/suite/tests/helpers/invoke.bash" get_dropbox_path
  [ "$status" -ne 0 ]
}

@test "pip backup without Dropbox fails without calling pip or creating roots" {
  run_function pip_backup_func
  [ "$status" -ne 0 ]
  [[ $output == *Skipped* && $output != *'List saved'* ]]
  assert_not_called pip
  [ ! -e "$HOME/Library/CloudStorage/Dropbox" ]
}

@test "pip inventories use existing Dropbox and correct Home or Office suffix" {
  write_dropbox
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  make_mock pip <<< '[[ $1 == freeze ]] || exit 88; printf "fixture-package==1.0\n"'
  local account suffix
  for account in fixture-home fixture-office; do
    export LOGNAME=$account
    suffix=${account#fixture-}
    run_function pip_backup_func
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/Dropbox Fixture/Private/_SyncThat/confInfos/pipCompleteList_$suffix.txt")" = fixture-package==1.0 ]
  done
}
