#!/usr/bin/env bats
load helpers/setup
load helpers/compat

@test "all registry entries have unique IDs nonempty labels and defined handlers" {
  run_probe <<'BASH'
declare -A seen=()
for id in "${ACTION_IDS[@]}"; do
  [[ -z ${seen[$id]:-} && -n ${ACTION_LABEL[$id]} ]] || exit 1
  seen[$id]=1
  declare -F "${ACTION_HANDLER[$id]}" >/dev/null || exit 1
done
[[ ${#seen[@]} == 33 ]]
BASH
  [ "$status" -eq 0 ]
}

@test "list IDs exactly match canonical registry order" {
  run_function build_menu_records
  [ "$status" -eq 0 ]
  local expected
  expected=$(printf '%s\n' "$output" | cut -f1)
  run "$TEST_BASH" "$SCRIPT" --list
  [ "$status" -eq 0 ]
  [ "$(printf '%s\n' "$output" | awk '/^[[:space:]]*[0-9]+[[:space:]]+-/ {print $1}')" = "$expected" ]
}

@test "generic dispatcher invokes exactly the chosen registered handler for every ID" {
  run_probe <<'BASH'
# Record dispatch identity without exercising workstation action implementations.
record_action() { printf '%s\n' "$1" >> "$HOME/dispatched"; }
for id in "${ACTION_IDS[@]}"; do ACTION_HANDLER[$id]=record_action; done
for id in "${ACTION_IDS[@]}"; do dispatch_action "$id" || exit 1; done
printf '%s\n' "${ACTION_IDS[@]}" > "$HOME/expected"
cmp "$HOME/expected" "$HOME/dispatched"
BASH
  [ "$status" -eq 0 ]
  assert_not_called sudo
}

@test "unknown empty and missing dispatch IDs fail closed" {
  local id
  for id in 9999 ''; do
    run_function dispatch_action "$id"
    [ "$status" -ne 0 ]
    [[ $output == *FATAL* ]]
  done
  run_function dispatch_action
  [ "$status" -ne 0 ]
  assert_not_called bashrc_resync.sh
}

@test "a removed handler function is rejected without falling back to another action" {
  run_probe <<'BASH'
unset -f action_bashrc_compare
dispatch_action 2
touch "$HOME/continued"
BASH
  [ "$status" -eq 1 ]
  [[ $output == *'not defined'* ]]
  [ ! -e "$HOME/continued" ]
  assert_not_called bashrc_resync.sh
}

@test "registration rejects duplicates empty labels missing functions and record separators" {
  run_function register_action 2 category label action_bashrc_compare
  [ "$status" -ne 0 ]
  run_function register_action 900 category '' action_bashrc_compare
  [ "$status" -ne 0 ]
  run_function register_action 900 category label absent_function
  [ "$status" -ne 0 ]
  run_function register_action 900 category $'bad\tlabel' action_bashrc_compare
  [ "$status" -ne 0 ]
  assert_not_called bashrc_resync.sh
}
