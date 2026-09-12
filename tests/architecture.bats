#!/usr/bin/env bats
load helpers/setup

@test "brew architecture report includes only x86-only executable files" {
  mkdir -p "$HOME/packages/fixture/bin"
  local name
  for name in intel arm universal; do
    printf fixture > "$HOME/packages/fixture/bin/$name"
    chmod +x "$HOME/packages/fixture/bin/$name"
  done
  make_mock brew <<'MOCK'
case "$*" in
  'list --formula') echo fixture ;;
  '--prefix fixture') echo "$HOME/packages/fixture" ;;
  *) exit 89 ;;
esac
MOCK
  make_mock lipo <<'MOCK'
case ${2##*/} in intel) echo x86_64;; arm) echo arm64;; universal) echo 'arm64 x86_64';; *) exit 1;; esac
MOCK
  run_function report_x86_brews_func
  [ "$status" -eq 0 ]
  [[ $output == *'fixture: intel'* && $output != *universal* && $output != *'fixture: arm'* ]]
  assert_called lipo
}

@test "absent optional port nix and tlmgr skip without privilege escalation" {
  run ! command -v port
  run ! command -v nix
  run ! command -v tlmgr
  local function
  for function in ports_update_func nix_upgrade_func texlive_update_func; do
    run_function "$function"
    [ "$status" -eq 0 ]
    [[ $output == *Skipped* || $output == *'tlmgr not found'* ]]
  done
  assert_not_called sudo
}
