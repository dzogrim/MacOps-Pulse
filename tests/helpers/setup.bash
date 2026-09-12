# shellcheck source=tests/helpers/safety.bash
source "${BASH_SOURCE[0]%/*}/safety.bash"
require_isolation || exit 90
bats_require_minimum_version 1.11.0
# shellcheck source=tests/helpers/mocks.bash
source "${BASH_SOURCE[0]%/*}/mocks.bash"

# Give every test a private home, command namespace and call journal.
setup() {
  CASE_ROOT=$(mktemp -d "$TEST_ROOT/cases/case.XXXXXX")
  export CASE_ROOT HOME="$CASE_ROOT/home" TMPDIR="$CASE_ROOT/tmp"
  export PATH="$CASE_ROOT/bin:/usr/bin:/bin" MOCK_LOG_DIR="$CASE_ROOT/calls"
  export SCRIPT="$TEST_ROOT/suite/refresh_system.sh" LOGNAME=fixture-home USER=fixture-home
  export ENVHOME=fixture-home ENVOFFICE=fixture-office NON_INTERACTIVE=1
  mkdir -p "$HOME/Desktop" "$HOME/Pictures" "$HOME/Documents/Screenshots" \
    "$HOME/.config/AdminHelpers" "$TMPDIR" "$CASE_ROOT/bin" "$MOCK_LOG_DIR"
  ln -s "$TEST_BASH" "$CASE_ROOT/bin/bash"
  ln -s "$TEST_ROOT/runtime/bin/jq" "$CASE_ROOT/bin/jq"
  local name
  for name in tput stty reset clear; do make_mock "$name" <<< 'exit 0'; done
  make_mock uname <<< 'printf "Darwin\n"'
  make_mock whoami <<< 'printf "fixture-home\n"'
  make_mock hostname <<< 'printf "fixture-host\n"'
  for name in sudo brew git mas mdutil gh install defaults osascript launchctl softwareupdate \
    mackup curl pip pip3 pipx bashrc_resync.sh; do
    make_mock "$name" <<< 'printf "Denied mock command\n" >&2; exit 89'
  done
  make_mock mv <<'MOCK'
for path in "$@"; do
  [[ $path == -* ]] && continue
  assert_sandbox_path "${path%/}" || exit 90
done
exec /bin/mv "$@"
MOCK
  make_mock rm <<'MOCK'
for path in "$@"; do
  [[ $path == -* ]] && continue
  assert_sandbox_path "${path%/}" || exit 90
done
exec /bin/rm "$@"
MOCK
}

# Remove only this test's owned case, after checking its disposable parent.
teardown() {
  [[ ${CASE_ROOT:-} == "$TEST_ROOT/cases/case."* ]] || return 1
  assert_sandbox_path "$CASE_ROOT" || return 1
  /bin/rm -rf -- "$CASE_ROOT"
}

# Run the real function in a child shell so fatal paths cannot kill Bats.
run_function() {
  run "$TEST_BASH" --noprofile --norc "$TEST_ROOT/suite/tests/helpers/invoke.bash" "$@"
}

# Write the complete synthetic AdminHelpers account/path configuration.
write_admin_env() {
  cat > "$HOME/.config/AdminHelpers/env" <<'ENV'
ADM_SHELL_USER_PERSO=fixture-home
ADM_SHELL_USER_PROv1=fixture-office
ADM_SHELL_SCPT_PERSO="$HOME/helpers"
ADM_SHELL_SCPT_PROv1="$HOME/office-helpers"
ENV
}

# Point Dropbox metadata at an existing synthetic directory, using real staged jq.
write_dropbox() {
  mkdir -p "$HOME/Library/Application Support/Dropbox" "$HOME/Dropbox Fixture"
  jq -n --arg path "$HOME/Dropbox Fixture" '{personal:{path:$path}}' \
    > "$HOME/Library/Application Support/Dropbox/info.json"
}
