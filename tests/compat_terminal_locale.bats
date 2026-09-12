#!/usr/bin/env bats
load helpers/setup
load helpers/compat

@test "Apple Terminal iTerm unknown and empty terminal values preserve structured identity" {
  local terminal expected=''
  for terminal in Apple_Terminal iTerm.app unknown ''; do
    # Bats runs each case in a separate process; this override is intentionally local.
    # shellcheck disable=SC2030,SC2031
    export TERM_PROGRAM=$terminal
    run_probe <<'BASH'
for id in "${ACTION_IDS[@]}"; do printf '%s\t%s\t%s\n' "$id" "${ACTION_LABEL[$id]}" "${ACTION_HANDLER[$id]}"; done
default_menu_position
BASH
    [ "$status" -eq 0 ]
    if [[ -z $expected ]]; then expected=$output; else [ "$output" = "$expected" ]; fi
    run_function debug_validate_choice_map
    [ "$status" -eq 0 ]
  done
}

@test "non-TTY TERM dumb help is readable and list keeps numeric mapping" {
  export TERM=dumb
  run "$TEST_BASH" "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ $output == *Usage:* && $output != *$'\033['* ]]
  run_traced_cli --list
  [ "$status" -eq 0 ]
  [[ $output != *$'\033['* ]]
  assert_zero_actions
  assert_not_called tput
}

@test "iTerm backup guard skips mackup without metadata or privilege probes" {
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export TERM_PROGRAM=iTerm.app
  make_mock pgrep <<< 'exit 88'
  make_mock mdls <<< 'exit 88'
  run_function dotfiles_func
  [ "$status" -eq 0 ]
  [[ $output == *'iTerm2 is running'* ]]
  assert_not_called mackup
  assert_not_called pgrep
  assert_not_called mdls
  assert_not_called sudo
}

@test "C English UTF-8 and French UTF-8 locales preserve registry mapping and Unicode labels" {
  local locale expected=''
  for locale in C en_US.UTF-8 fr_FR.UTF-8; do
    run /usr/bin/env LANG="$locale" LC_ALL="$locale" "$TEST_BASH" "$SCRIPT" --list
    [ "$status" -eq 0 ]
    [[ $output != *'cannot change locale'* ]]
    if [[ -z $expected ]]; then expected=$output; else [ "$output" = "$expected" ]; fi
    run /usr/bin/env LANG="$locale" LC_ALL="$locale" "$TEST_BASH" "$SCRIPT" --debug-choices
    [ "$status" -eq 0 ]
  done
}

@test "Unicode screenshot names keep quoting and BSD mv does not overwrite collisions" {
  export SCREENSHOTSDIR="$HOME/Pictures"
  local name="Screenshot 2025-03-12 l'été [été] 🐍.png"
  mkdir -p "$HOME/Pictures/2025/2025-03/2025-03-12"
  printf original > "$HOME/Pictures/2025/2025-03/2025-03-12/$name"
  printf new > "$HOME/Desktop/$name"
  printf dated > "$HOME/Desktop/Screenshot l'été [🌍].heic"
  touch -t 202303041200 "$HOME/Desktop/Screenshot l'été [🌍].heic"
  run_function tidy_screenshots_func
  [ "$status" -eq 0 ]
  [ "$(cat "$HOME/Pictures/2025/2025-03/2025-03-12/$name")" = original ]
  [ "$(cat "$HOME/Desktop/$name")" = new ]
  [ "$(cat "$HOME/Pictures/2023/2023-03/2023-03-04/Screenshot l'été [🌍].heic")" = dated ]
}

@test "Dropbox and filesystem Mackup preserve accents apostrophes brackets and spaces" {
  local storage="$HOME/l'été [archives] 🌍"
  mkdir -p "$storage" "$HOME/Library/Application Support/Dropbox"
  jq -n --arg path "$storage" '{personal:{path:$path}}' > "$HOME/Library/Application Support/Dropbox/info.json"
  run_function get_dropbox_path
  [ "$status" -eq 0 ]
  [ "$output" = "$storage" ]
  printf '[storage]\nengine = file_system\npath = %s\n' "$storage" > "$HOME/.mackup.cfg"
  run_function resolve_mackup_storage
  [ "$status" -eq 0 ]
  [ "$output" = "$storage" ]
}
