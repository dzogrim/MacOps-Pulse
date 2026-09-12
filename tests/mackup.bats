#!/usr/bin/env bats
load helpers/setup

@test "Dropbox iCloud and Copy engines resolve synthetic storage" {
  write_dropbox
  mkdir -p "$HOME/Library/Mobile Documents/com~apple~CloudDocs" "$HOME/Copy"
  local engine expected
  for engine in dropbox icloud copy; do
    printf '[storage]\nengine = %s\n' "$engine" > "$HOME/.mackup.cfg"
    case $engine in
      dropbox) expected="$HOME/Dropbox Fixture" ;;
      icloud) expected="$HOME/Library/Mobile Documents/com~apple~CloudDocs" ;;
      copy) expected="$HOME/Copy" ;;
    esac
    run_function resolve_mackup_storage
    [ "$status" -eq 0 ]
    [ "$output" = "$expected" ]
  done
}

@test "file_system requires a configured existing directory" {
  mkdir "$HOME/storage"
  printf '[storage]\nengine = file_system\npath = %s\n' "$HOME/storage" > "$HOME/.mackup.cfg"
  run_function resolve_mackup_storage
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/storage" ]
  mv "$HOME/storage" "$HOME/renamed"
  run_function resolve_mackup_storage
  [ "$status" -ne 0 ]
  printf '[storage]\nengine = file_system\n' > "$HOME/.mackup.cfg"
  run_function resolve_mackup_storage
  [ "$status" -ne 0 ]
}

@test "unsupported and empty Mackup engines fail" {
  cp "$TEST_ROOT/suite/tests/fixtures/mackup/unsupported.cfg" "$HOME/.mackup.cfg"
  run_function resolve_mackup_storage
  [ "$status" -ne 0 ]
  [[ $output == *'Unknown mackup storage engine'* ]]
  printf '[storage]\nengine =\n' > "$HOME/.mackup.cfg"
  run_function resolve_mackup_storage
  [ "$status" -ne 0 ]
}
