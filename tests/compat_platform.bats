#!/usr/bin/env bats
load helpers/setup
load helpers/compat

@test "startup remains independent of two- and three-component macOS version strings" {
  write_admin_env
  make_mock sw_vers <<'MOCK'
printf '%s\n' "$MOCK_OS_VERSION"
MOCK
  local version
  for version in 10.15.7 11.7.10 14.6 15.10.2 26.0; do
    export MOCK_OS_VERSION=$version
    run_function initialize_execution_environment
    [ "$status" -eq 0 ]
  done
  # No version parser/comparator exists in the current script.
  assert_not_called sw_vers
  assert_not_called brew
}

@test "Darwin startup does not branch on native or translated CPU identity" {
  write_admin_env
  make_mock uname <<'MOCK'
case ${1:-} in -m) printf '%s\n' "$MOCK_CPU";; *) echo Darwin;; esac
MOCK
  local cpu
  for cpu in arm64 x86_64; do
    export MOCK_CPU=$cpu
    run_function initialize_execution_environment
    [ "$status" -eq 0 ]
    assert_not_called brew
  done
  [[ $(cat "$MOCK_LOG_DIR/uname") != *-m* ]]
}

@test "BSD awk MacPorts grouping excludes universal binaries and documentation" {
  make_mock port <<'MOCK'
[[ $* == '-q contents fixture' ]] || exit 88
printf '  %s\n' "$HOME/ports/bin/intel" "$HOME/ports/bin/universal" "$HOME/ports/bin/arm" "$HOME/ports/share/doc/manual"
MOCK
  # Intercept xargs: never execute the absolute /usr/bin/file from this pipeline.
  make_mock xargs <<'MOCK'
[[ $* == '-0 -n 200 /usr/bin/file' ]] || exit 88
while IFS= read -r -d '' path; do
  case $path in
    */intel) printf '%s: Mach-O 64-bit executable x86_64\n' "$path" ;;
    */universal) printf '%s (for architecture x86_64): Mach-O x86_64\n%s (for architecture arm64): Mach-O arm64\n' "$path" "$path" ;;
    */arm) printf '%s: Mach-O 64-bit executable arm64\n' "$path" ;;
    *) exit 88 ;;
  esac
done
MOCK
  run_function report_x86_only_files_for_port_fast fixture
  [ "$status" -eq 0 ]
  [ "$output" = "$HOME/ports/bin/intel" ]
  assert_called xargs
}

@test "missing lipo yields no false x86-only report or fatal error" {
  mkdir -p "$HOME/pkg/bin"
  printf fixture > "$HOME/pkg/bin/tool"
  chmod +x "$HOME/pkg/bin/tool"
  make_mock brew <<'MOCK'
case $1 in list) echo fixture;; --prefix) echo "$HOME/pkg";; *) exit 88;; esac
MOCK
  make_minimal_path brew sort
  run /usr/bin/env PATH="$CASE_ROOT/minimal" "$TEST_BASH" "$TEST_ROOT/suite/tests/helpers/invoke.bash" report_x86_brews_func
  [ "$status" -eq 0 ]
  [ -z "$output" ]
}

@test "MacUpdater BSD awk filtering preserves multi-component versions as opaque text" {
  make_mock macupdater-client <<'MOCK'
printf '%s\n' 'Last Scan Date: fixture' '' 'Éditeur Pro v1.2.10 (Update to v1.10.0 pending)' 'Alpha v15.10.2' 'beta v2.3'
MOCK
  export MACUPDTAPP="$CASE_ROOT/bin/macupdater-client" MACUPDTAPPOPTS=--quiet
  run_function macup_list_func
  [ "$status" -eq 0 ]
  [[ $output != *'Last Scan Date'* && $output == *v1.2.10* && $output == *v1.10.0* && $output == *v15.10.2* ]]
  [ "${lines[0]}" = 'Alpha v15.10.2' ]
}

@test "BSD find handles formula paths with Unicode and ignores nonexecutables and empty files" {
  mkdir -p "$HOME/paquets été/bin"
  printf fixture > "$HOME/paquets été/bin/l'outil [1]"
  printf data > "$HOME/paquets été/bin/readme"
  touch "$HOME/paquets été/bin/empty"
  chmod +x "$HOME/paquets été/bin/l'outil [1]" "$HOME/paquets été/bin/empty"
  make_mock brew <<'MOCK'
case $1 in list) echo fixture;; --prefix) echo "$HOME/paquets été";; *) exit 88;; esac
MOCK
  make_mock lipo <<'MOCK'
[[ $2 == "$HOME/paquets été/bin/l'outil [1]" ]] || exit 88
printf 'x86_64\n'
MOCK
  run_function report_x86_brews_func
  [ "$status" -eq 0 ]
  [ "$output" = "fixture: l'outil [1] → x86_64" ]
  [ "$(wc -l < "$MOCK_LOG_DIR/lipo")" -eq 1 ]
}
