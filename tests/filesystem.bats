#!/usr/bin/env bats
load helpers/setup

@test "screenshots use encoded and stat dates while unrelated files stay put" {
  export SCREENSHOTSDIR="$HOME/Pictures"
  touch "$HOME/Desktop/Screenshot 2025-03-12 at 10.20.30.png" "$HOME/Desktop/Capture d’écran 2024-11-02.jpg" "$HOME/Desktop/arbitrary.heic" "$HOME/Desktop/notes.txt"
  touch -t 202201020304 "$HOME/Desktop/Screenshot undated.heic"
  run_function tidy_screenshots_func
  [ "$status" -eq 0 ]
  [ -f "$HOME/Pictures/2025/2025-03/2025-03-12/Screenshot 2025-03-12 at 10.20.30.png" ]
  [ -f "$HOME/Pictures/2024/2024-11/2024-11-02/Capture d’écran 2024-11-02.jpg" ]
  [ -f "$HOME/Pictures/2022/2022-01/2022-01-02/Screenshot undated.heic" ]
  [ -f "$HOME/Desktop/arbitrary.heic" ]
  [ -f "$HOME/Desktop/notes.txt" ]
  assert_called mv
}

@test "Desktop reporting skips mocked aliases and restores nullglob" {
  touch "$HOME/Desktop/alias" "$HOME/Desktop/ordinary"
  make_mock file <<'MOCK'
case ${*: -1} in */alias) echo 'MacOS Alias file';; *) echo 'ASCII text';; esac
MOCK
  # Expand variables in the isolated child, not while constructing its program.
  # shellcheck disable=SC2016
  run "$TEST_BASH" -c 'source "$SCRIPT"; shopt -u nullglob; userDesktopNotAliases_func || exit 1; if shopt -q nullglob; then exit 1; fi; shopt -s nullglob; userDesktopNotAliases_func; shopt -q nullglob'
  [ "$status" -eq 0 ]
  [[ $output == *ordinary* && $output != *alias* ]]
  assert_called file
}
