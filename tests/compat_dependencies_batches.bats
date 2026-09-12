#!/usr/bin/env bats
load helpers/setup
load helpers/compat

@test "mandatory command checking reports each missing tool on a controlled PATH" {
  make_minimal_path
  local tool
  for tool in jq awk gh git install fzf gum brew mas mackup; do
    run /usr/bin/env PATH="$CASE_ROOT/minimal" "$TEST_BASH" "$TEST_ROOT/suite/tests/helpers/invoke.bash" checkTools "$tool"
    [ "$status" -eq 1 ]
    [[ $output == *'missing tools:'* && $output == *"$tool"* ]]
  done
}

@test "helper installation missing prerequisites fails before clone or destination creation" {
  write_admin_env
  make_minimal_path
  run /usr/bin/env PATH="$CASE_ROOT/minimal" "$TEST_BASH" "$SCRIPT" --install-deps-scpt
  [ "$status" -eq 1 ]
  [[ $output == *awk* && $output == *gh* && $output == *git* && $output == *install* ]]
  [ ! -e "$HOME/helpers" ]
  assert_not_called gh
  assert_not_called install
  assert_not_called sudo
}

@test "Nix missing helpers skip and noninteractive maintenance never requests deep clean" {
  make_mock nix <<< 'exit 88'
  run_function nix_upgrade_func
  [ "$status" -eq 0 ]
  [[ $output == *'missing from PATH'* ]]
  make_mock check-trusted-user-nix.sh <<< 'exit 0'
  make_mock maintenance-nix-macos.sh <<'MOCK'
[[ $# == 0 ]] || exit 88
MOCK
  run_function nix_upgrade_func
  [ "$status" -eq 0 ]
  assert_called maintenance-nix-macos.sh
  assert_not_called nix
  assert_not_called sudo
}

@test "privileged Python action delegates exact version arguments and propagates sudo failure" {
  make_mock set-python-123.sh <<< 'exit 88'
  make_mock sudo <<'MOCK'
[[ $* == 'set-python-123.sh 313' ]] || exit 88
exit "${SUDO_STATUS:-0}"
MOCK
  run_function action_python_version 19
  [ "$status" -eq 0 ]
  assert_called sudo
  assert_not_called set-python-123.sh
  export SUDO_STATUS=7
  run_function action_python_version 19
  [ "$status" -eq 1 ]
  [[ $output == *FATAL* ]]
  assert_not_called set-python-123.sh
}

@test "comparison batch preserves exact order once and returns success after soft failure" {
  mock_batch_commands bashrc_resync.sh compare_brew_home_office.sh compare_ports_home_office.sh
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export FAIL_STEP=bashrc_resync.sh
  run_function run_all_comparisons_func
  [ "$status" -eq 0 ]
  [[ $output == *'Step [2] failed'* ]]
  [ "$(cat "$HOME/batch-order")" = $'bashrc_resync.sh\ncompare_brew_home_office.sh\ncompare_ports_home_office.sh' ]
  assert_not_called sudo
}

@test "backup batch keeps all four steps after unavailable Dropbox soft failures" {
  mock_batch_commands ports-infoBackup.sh brew_conf_export.sh
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export TERM_PROGRAM=iTerm.app FAIL_STEP=ports-infoBackup.sh
  run_probe <<'BASH'
exec 9>"$CASE_ROOT/trace"
BASH_XTRACEFD=9
PS4='TRACE:${FUNCNAME[0]:-main}: '
set -x
run_all_backups_func
BASH
  [ "$status" -eq 0 ]
  [[ $output == *'Step [9] failed'* && $output == *'Step [20] failed'* ]]
  [ "$(cat "$HOME/batch-order")" = $'ports-infoBackup.sh\nbrew_conf_export.sh' ]
  # Observe every real wrapper call, including steps skipped before external delegation.
  [ "$(awk '$1 == "TRACE:run_all_backups_func:" && $2 == "run_soft_step" {print $3}' "$CASE_ROOT/trace")" = $'1\n9\n13\n20' ]
  assert_not_called pip
  assert_not_called sudo
}

@test "update batch preserves ordering and continues past recoverable command failure" {
  mock_batch_commands softwareupdate mas brew-update.sh
  # Bats runs each case in a separate process; this override is intentionally local.
  # shellcheck disable=SC2030,SC2031
  export FAIL_STEP=mas
  run_probe <<'BASH'
exec 9>"$CASE_ROOT/trace"
BASH_XTRACEFD=9
PS4='TRACE:${FUNCNAME[0]:-main}: '
set -x
run_all_updates_func
BASH
  [ "$status" -eq 0 ]
  [[ $output == *'Step [5] failed'* && $output == *'Nix is not installed'* ]]
  [ "$(cat "$HOME/batch-order")" = $'softwareupdate\nmas\nbrew-update.sh' ]
  [ "$(awk '$1 == "TRACE:run_all_updates_func:" {if ($2 == "run_soft_step") print $3; else if ($2 == "texlive_update_func") print "tex"}' "$CASE_ROOT/trace")" = $'4\n5\n8\ntex\n12\n16' ]
  assert_not_called sudo
}

@test "hard TeX Live failure stops update batch before later steps" {
  mock_batch_commands softwareupdate mas brew-update.sh
  make_mock tlmgr <<< 'exit 88'
  run_function run_all_updates_func
  [ "$status" -eq 1 ]
  [[ $output == *'TeX Live update failed'* ]]
  [ "$(cat "$HOME/batch-order")" = $'softwareupdate\nmas' ]
  assert_called sudo
  assert_not_called brew-update.sh
  assert_not_called tlmgr
}
