#!/usr/bin/env bash

# SPDX-License-Identifier: MIT
# SPDX-FileCopyrightText: 2015-2026 dzogrim
# SPDX-FileContributor: dzogrim <dzogrim@dzogrim.pw>
# ----------------------------------------------------------------------------
# refresh_system.sh — macOS Maintenance Toolkit
# ----------------------------------------------------------------------------
# A mature, modular Bash utility for refreshing and maintaining macOS systems.
#
# Menus focus action 2 and exit after 50 seconds without confirmation;
# and timeout never executes the highlighted action.
#
# Non-interactive usage: --run ID executes one action; --help, --list and
# --debug-choices inspect metadata without environment or maintenance checks.
# Architecture: register_action declares stable IDs and real handlers once;
# structured ID/category/label records feed the menus, then generic dispatch.
#
# Main task categories include:
#   - dotfiles and preferences synchronization (Mackup 0.11.1)
#   - updates for macOS, App Store, Homebrew, MacPorts, Nix, and TeX Live
#   - Python version pinning and package inventory export
#   - validation checks (SSL certs, Spotlight, shell env, architecture analysis)
#   - macOS desktop, screenshot, and local environment tidying
#   - Gist-backed helper-script checks, installation, and inventory display
#
# Safety principles: validate required commands before use, keep privileged
# actions explicit, preserve clear error handling, and avoid implicit destructive
# operations.
#
# Requirements:
# - GNU Bash 5; normal maintenance requires macOS and checks git, brew, mas,
#   mdutil and jq. Individual operations also use native macOS tools and sudo.
# - Interactive UI: gum or fzf, depending on the selected path.
# - Action-specific tools include mackup and the external helpers listed below.
# - --check-deps-scpt needs awk and PATH only; --install-deps-scpt validates
#   AdminHelpers accounts/paths and checks awk, gh, git and install.
#
# Optional:
# - MacPorts support, including commands using 'port', may become **deprecated** or
#   be removed in a future version and is not considered a core requirement anymore.
# - MacUpdater 3.5.0 (proprietary) → deprecated since Jan. 2026!
#
# Operational notes:
# - Screenshot tidying will be influenced by SCREEN_SRC, SCREEN_DST, SCREEN_EXTS.
# - 'gist-sync_status' requires an interactive inventory mode choice.
#
# - Dropbox exports require an existing root; only descendant directories may
#   be created. Batch soft failures report errors and allow subsequent steps.
#
# Environment: normal execution and helper installation source and validate
# "${HOME}/.config/AdminHelpers/env". Perso/Pro accounts select local paths;
# some helper/application paths remain site-specific and must be configured.
#
# Author      : dzogrim (Sébastien L.)
# Maintainer  : dzogrim (Sébastien L.) — MIT License
# -------------------------------------------------------------------------------------------------
# Required subscripts in PATH:
#  • bashrc_resync.sh:             https://gist.github.com/dzogrim/f158a971bf25c69aaa5a6eb47840660f
#  • brew-update.sh:               https://gist.github.com/dzogrim/00e3d5dd9e2b14680204fe4d5d58f8d3
#  • brew_conf_export.sh:          https://gist.github.com/dzogrim/834ca2bffde8055e013fe97501aaa0f1
#  • certs_validity.sh:            https://gist.github.com/dzogrim/c3a841e72fac41e8259483fea8aa92fd
#  • check-trusted-user-nix.sh:    https://gist.github.com/dzogrim/0933ac4c6c0d63edafdd4b81774e2341
#  • check_env_shell.sh:           https://gist.github.com/dzogrim/0d9e1664cdf20084fce8212f41f3bd66
#  • compare_brew_home_office.sh:  https://gist.github.com/dzogrim/8e54c7d911d559af6fe44de13e760a16
#  • compare_ports_home_office.sh: https://gist.github.com/dzogrim/9acbd2abe5b5a878016c4e5a395defd3
#  • gist-sync:                    https://gist.github.com/dzogrim/d77c9df3d4b761cdb3269f8b666558a2
#  • git_refresh.sh:               https://gist.github.com/dzogrim/1200bf4171b69ea9ded23e53b31746cb
#  • maintenance-nix-macos.sh:     https://gist.github.com/dzogrim/d106380d7a281f50d4f860635056af81
#  • nix-manager-adm:              https://gist.github.com/dzogrim/72eeac8a844c6ee9bca0e4451994ce65
#  • ports-infoBackup.sh:          https://gist.github.com/dzogrim/41b47214db89d75f4aa929acf2745f78
#  • ports-update.sh:              https://gist.github.com/dzogrim/60151869043e1412236dac0a5100ba5c
#  • remove-MAU2.sh:               https://gist.github.com/dzogrim/92cd4143ee685cd48e0ede5614b8bb28
#  • reset_spotlight_position.sh:  https://gist.github.com/dzogrim/21b57261ac80b161e8c95d164f2524c3
#  • set-python-123.sh:            https://gist.github.com/dzogrim/215446f4dc0dd6bf945915f34bb84ff1
# -------------------------------------------------------------------------------------------------
# → do not shell check variables used inside `printf` format strings:
# shellcheck disable=SC2059

readonly VERSION="4.0.0 (2026-09-12)"

# ============================================================================
#  Admin Environment
# ============================================================================
readonly ADMIN_HELPERS_ENV="${HOME}/.config/AdminHelpers/env"
# Reject an empty account name and identify the AdminHelpers variable to correct.
validate_local_account() {
    local account_name=$1
    local variable_name=$2

    if [[ -z "$account_name" ]]; then
        printf 'Error: %s is empty.\n' "$variable_name" >&2
        return 1
    fi
}

# AdminHelpers is required for execution, including account-specific helper installs.
initialize_admin_environment() {
  if [[ ! -r "$ADMIN_HELPERS_ENV" ]]; then
      printf 'Error: AdminHelpers environment is missing or unreadable: %s\n' \
          "$ADMIN_HELPERS_ENV" >&2
      exit 1
  fi

  # shellcheck source=/dev/null
  source "$ADMIN_HELPERS_ENV" || {
      printf 'Error: failed to source AdminHelpers environment: %s\n' \
          "$ADMIN_HELPERS_ENV" >&2
      exit 1
}

: "${ADM_SHELL_USER_PROv1:?Missing ADM_SHELL_USER_PROv1}"
: "${ADM_SHELL_USER_PERSO:?Missing ADM_SHELL_USER_PERSO}"
: "${ADM_SHELL_SCPT_PROv1:?Missing ADM_SHELL_SCPT_PROv1}"
: "${ADM_SHELL_SCPT_PERSO:?Missing ADM_SHELL_SCPT_PERSO}"

# ----------------------------------------------------------------------------
#  Account Validation
# ----------------------------------------------------------------------------

validate_local_account "$ADM_SHELL_USER_PERSO" "ADM_SHELL_USER_PERSO" || exit 1
validate_local_account "$ADM_SHELL_USER_PROv1" "ADM_SHELL_USER_PROv1" || exit 1

# ----------------------------------------------------------------------------
#  Validated Environment Accounts
# ----------------------------------------------------------------------------
readonly ENVHOME="$ADM_SHELL_USER_PERSO"
readonly ENVOFFICE="$ADM_SHELL_USER_PROv1"

}

# ============================================================================
#  More Settings
# ============================================================================

# Python version
readonly PYVERS="313"       # Ports compatible
readonly PYVERS_H="3.13.9"  # Human friendly

# Default focus never implies execution; both menus exit when this deadline expires.
# Keep the production deadline while allowing isolated callers to shorten it.
readonly TIMEOUT_SEC="${TIMEOUT_SEC:-50}"
readonly DEFAULT_SELECTION=2

# Candidate locations are configuration, never proof that Dropbox is available.
readonly DROPBOX_DEFAULT_ROOT="$HOME/Library/CloudStorage/Dropbox"
readonly DROPBOX_CONFINFO_RELATIVE="Private/_SyncThat/confInfos"

# Metadata modes need neither a terminal nor a configured maintenance machine.
# Load execution-only account settings, terminal state and macOS platform checks.
initialize_execution_environment() {
  initialize_admin_environment
  # Reset terminal and exit cleanly if interrupted (CTRL+C or termination signal).
  trap 'stty sane; reset; echo "Aborted. Terminal reset."; exit 1' INT TERM

  # Text color variables
  txtbld=$(tput bold)              # bold
  bldred=${txtbld}$(tput setaf 1)  # red
  bldblu=${txtbld}$(tput setaf 4)  # blue
  bldbrw=${txtbld}$(tput setaf 3)  # brown
  bldgrn=${txtbld}$(tput setaf 2)  # green
  bldcya=${txtbld}$(tput setaf 6)  # cyan
  txtrst=$(tput sgr0)              # reset

  # Ensure the script is running on macOS only.
  if [[ "$(uname)" != "Darwin" ]]; then
    printf "\n${bldred}Error:${txtrst} This program is intended for macOS only. Exiting.\n" >&2
    exit 1
  fi

  resolve_login_name
}

# Resolve a missing login name consistently for normal execution and helper installation.
resolve_login_name() {
  # Ensure LOGNAME is available
  if [ -z "$LOGNAME" ]; then
      LOGNAME=$(whoami)
      printf "\n${bldbrw}Warning:${txtrst} LOGNAME was not set. Using 'whoami': %s\n" "$LOGNAME" >&2
  fi
}

# Abort with the complete list of missing executables required by the current path.
checkTools()
{
  local misstools=""
  for entry in "$@"; do
    if [[ ! -x "$(command -v "${entry}" 2>/dev/null)" ]];
    then
      misstools="${misstools} ${entry}"
    fi
  done

  if [ -z "${misstools}" ]; then
    return
  else
    fatal "$(basename "${0}") requires the following missing tools: ${misstools}"
  fi
}

# Print CLI usage and environment notes, then exit successfully without machine checks.
usage() {
  local reset blue cyan green brown title
  local script_name="${0##*/}"
  local cmd_width=58

  if [[ -t 1 ]]; then
    reset=$'\033[0m'
    blue=$'\033[1;34m'
    cyan=$'\033[1;36m'
    green=$'\033[1;32m'
    brown=$'\033[1;33m'
    title=$'\033[1;97;44m'
  else
    reset=''
    blue=''
    cyan=''
    green=''
    brown=''
    title=''
  fi

  clear
  printf '\n%s  %s %s  %s\n\n' \
    "$title" \
    "$script_name" \
    "$VERSION" \
    "$reset"

  # Usage
  printf '%sUsage:%s\n' "$blue" "$reset"
  printf '  %s%-*s%s# %s\n' "$green" "$cmd_width" "$script_name" "$reset" \
    "Launch interactive menu using default mode"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --gum" "$reset" \
    "Explicitly launch using 'gum'"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --fzf" "$reset" \
    "Explicitly launch using 'fzf'"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --list" "$reset" \
    "Print numeric action IDs for --run"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --run <ID>" "$reset" \
    "Run one numeric action directly"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --check-deps-scpt" "$reset" \
    "Check Gist scripts declared in the header"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --install-deps-scpt" "$reset" \
    "Install missing Gist scripts for this system"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --debug-choices" "$reset" \
    "Validate menu/action mapping"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " -h | --help" "$reset" \
    "Show this help"

  printf '\n%sNotes:%s\n' "$blue" "$reset"
  printf "  %s'--run'%s accepts exactly one numeric ID from %s'--list'%s and sets %s'NON_INTERACTIVE=1'%s.\n" \
    "$cyan" "$reset" "$cyan" "$reset" "$brown" "$reset"
  printf '  The environment variables file comes from: %s%s%s\n' \
    "$brown" "${ADMIN_HELPERS_ENV}" "$reset"

  printf '\n%sExamples:%s\n' "$blue" "$reset"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --list" "$reset" \
    "Print numeric action IDs for --run"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --run 2" "$reset" \
    "Run 'Compare ~/.bashrc.d and other config with synced version'"
  printf '  %s%s%s%-*s%s# %s\n' "$green" "$script_name" "$cyan" \
    "$((cmd_width - ${#script_name}))" " --run 16" "$reset" \
    "Run 'Upgrade Nix environment'"

  exit 0
}

# Home uses the shared application tree; Office uses the per-user installation.
# Keep the client filtering options consistent between these installations.
envMacUpdaterApp()
{
  MACUPDTAPPOPTS="--hide-uptodate-apps --hide-unsupported-apps --quiet"
  if [[ "${LOGNAME}" == "${ENVHOME}" ]]; then
    MACUPDTAPP="/Applications/Unified Tools/System/MacUpdater.app/Contents/Resources/macupdater_client"
  elif [[ "${LOGNAME}" == "${ENVOFFICE}" ]]; then
    MACUPDTAPP="$HOME/Applications/MacUpdater.app/Contents/Resources/macupdater_client"
  else
    printf "\n${bldbrw}Warning:${txtrst} MacUpdater not found (or not configured). Some features may not work properly.\n\n"
    MACUPDTAPP=""
  fi
}

# Office stores screenshots in Documents; Home uses Pictures. A missing directory
# remains an error here, but startup historically continues to unrelated actions.
envScreenshotsDir() {
  if [[ "${LOGNAME}" == "${ENVOFFICE}" ]]; then
    SCREENSHOTSDIR="$HOME/Documents/Screenshots"
  elif [[ "${LOGNAME}" == "${ENVHOME}" ]]; then
    SCREENSHOTSDIR="$HOME/Pictures"
  else
    printf "\n${bldbrw}Warning:${txtrst} Unknown environment (LOGNAME=%s). SCREENSHOTSDIR not set.\n\n" "$LOGNAME" >&2
    SCREENSHOTSDIR=""
    return 2
  fi

  if [[ ! -d "$SCREENSHOTSDIR" ]]; then
    printf "\n${bldred}Error:${txtrst} Directory not found: %s\n\n" "$SCREENSHOTSDIR" >&2
    SCREENSHOTSDIR=""
    return 3
  fi
}

# Reject an unavailable MacUpdater client before invoking its scan or list commands.
checkMacUpdaterApp() {
  if [[ ! -x "${MACUPDTAPP}" ]]; then
    printf "\n${bldred}Error:${txtrst} MacUpdater app not found or not executable. Please verify its path.\n"
    return 1
  fi
  return 0
}

# Check core maintenance tools and resolve account-specific application and screenshot paths.
initChecks() {
  checkTools git brew mas mdutil jq
  envMacUpdaterApp
  envScreenshotsDir
}

# Warn before an operation requests elevated privileges through sudo.
warningRootDisplay() {
  printf "\n${bldbrw}You need to gain root privileges to perform this action!${txtrst}\n"
}

# Explain why an unrecognized account has no environment-specific work to perform.
warningBadEnv() {
  printf "\n${bldbrw}Sorry!${txtrst} Nothing to do in this unknown environment.\n"
}

# Restore terminal sanity when possible, print the failure, and terminate with status 1.
fatal() {
  stty sane 2>/dev/null
  printf "\n${bldred}[FATAL]:${txtrst} %s\n" "$1"
  exit 1
}

# Print the completion message after a successful action step.
infoFinished() {
  printf "\n${bldgrn}Done.${txtrst}\n"
}

# Nix and its maintenance helpers are optional: skip cleanly if unavailable.
# Scripted runs never request deep cleaning; interactive runs keep the timed prompt.
nix_upgrade_func() {
  if ! command -v nix >/dev/null 2>&1; then
    printf "\n${bldbrw}Skipped:${txtrst} Nix is not installed on this system.\n"
    return 0
  fi

  local helper
  for helper in maintenance-nix-macos.sh check-trusted-user-nix.sh; do
    if ! command -v "$helper" >/dev/null 2>&1; then
      printf "\n${bldbrw}Warning:${txtrst} Nix is installed but '%s' is missing from PATH. Skipping Nix maintenance.\n" "$helper" >&2
      return 0
    fi
  done

  check-trusted-user-nix.sh
  if [[ "$NON_INTERACTIVE" != "1" ]]; then
    read -r -t 30 -p "Deep clean? [y/N] " choice
    case "$choice" in
      [Yy]*) printf "\n" ; maintenance-nix-macos.sh --optimize --clean ;;
      *)     printf "\n" ; maintenance-nix-macos.sh ;;
    esac
  else
    maintenance-nix-macos.sh
  fi
}

# Run the FCC installer, update an available Cua Driver, and report local setup readiness.
fcc_online_upgrade_func() {
  checkTools curl sh

  FCC_INST="https://raw.githubusercontent.com/Alishahryar1/free-claude-code/main/scripts/install.sh"
  sh -c "$(curl -fsSL "${FCC_INST}")" </dev/null | cat

  FCClink="$HOME/Desktop/Free Claude Code.app"
  if [[ -L "$FCClink" ]]; then
    printf '\nRemoving Free Claude Code desktop symlink.\n'
    rm -- "$FCClink"
  fi

  if command -v cua-driver >/dev/null 2>&1; then
    printf '\n==> Upgrading Cua Driver\n'
    cua-driver update --apply
  fi

  FCC_ENV="$HOME/.fcc/.env"

  if [[ -f "$FCC_ENV" ]]; then
    API_KEYS=$(grep -Ec '^[[:space:]]*[^#=]*API_KEY[^=]*=.+$' "$FCC_ENV" || true)
  else
    API_KEYS=0
  fi

  if (( API_KEYS > 0 )); then
    printf '\nYour environment is set with %d API keys.\n' "$API_KEYS"
  else
    printf '\nYour environment is not ready!\n'
  fi

  if compgen -G "$HOME/.bashrc*bak" >/dev/null; then
    printf 'WARNING: .bashrc backup file(s) found in your home directory!\n'
  fi
}

# Resolve an existing, readable Dropbox root; emit no path and fail if unavailable.
get_dropbox_path() {
  local json_path="$HOME/Library/Application Support/Dropbox/info.json"
  local dropbox_path=""
  if [[ -f "$json_path" ]] && command -v jq >/dev/null 2>&1; then
    # A missing/non-string path or malformed JSON is not a usable configuration.
    dropbox_path=$(jq -er '.personal.path | select(type == "string" and length > 0)' \
      "$json_path" 2>/dev/null) || dropbox_path=""
  elif [[ -f "$json_path" ]]; then
    # Preserve the historical no-jq extraction; candidates still require a real root.
    dropbox_path=$(grep -E '^\s*"path"\s*:' "$json_path" | \
      sed -E 's/.*"path": "([^"]+)".*/\1/' | head -n1)
  fi
  if [[ "$dropbox_path" == /* && -d "$dropbox_path" && -r "$dropbox_path" && -x "$dropbox_path" ]]; then
    printf '%s\n' "$dropbox_path"
    return 0
  fi
  if [[ -d "$DROPBOX_DEFAULT_ROOT" && -r "$DROPBOX_DEFAULT_ROOT" && -x "$DROPBOX_DEFAULT_ROOT" ]]; then
    printf '%s\n' "$DROPBOX_DEFAULT_ROOT"
    return 0
  fi
  return 1
}

# Report x86_64-only Mach-O files from a port, excluding documentation and headers.
report_x86_only_files_for_port_fast() {
  local p="$1"
  port -q contents "$p" 2>/dev/null \
  | sed 's/^ *//' \
  | /usr/bin/grep -Ev '^$|/(share|doc|man|include|examples|pkgconfig|cmake|headers?)/' \
  | /usr/bin/grep -E '/(bin/|sbin/|lib/.*\.(dylib|so)(\.[0-9]+)?$|libexec/|Frameworks/|Library/Extensions/|plugins?/)' \
  | tr '\n' '\0' \
  | xargs -0 -n 200 /usr/bin/file 2>/dev/null \
  | /usr/bin/grep 'Mach-O' \
  | awk '
      {
        line=$0; key=line
        sub(/:.*$/,"",key)
        sub(/[[:space:]]*\(for architecture [^)]+\).*/,"",key)
        buf[key]=buf[key] "\n" line
      }
      END {
        for (f in buf) {
          has_x = buf[f] ~ /x86_64/
          has_a = buf[f] ~ /arm64/
          if (has_x && !has_a) print f
        }
      }' \
  | sort -u
}

# MacPorts is optional. Individual operations convert absence into a clean skip.
macports_available_func() {
  if ! command -v port >/dev/null 2>&1; then
    printf "\n${bldbrw}Skipped:${txtrst} MacPorts is not installed on this system.\n"
    return 1
  fi
}

# Export MacPorts inventories through the helper, skipping when MacPorts is absent.
backup_ports_func() {
  macports_available_func || return 0
  checkTools ports-infoBackup.sh
  # The helper requires an existing writable ADM_PUB_STORCONF_DIR; it never mkdirs it.
  ports-infoBackup.sh
}

# Compare MacPorts with its reference environment when the optional installation exists.
compare_ports_func() {
  macports_available_func || return 0
  checkTools compare_ports_home_office.sh
  compare_ports_home_office.sh
}

# List active ports containing Intel-only binaries, skipping absent MacPorts.
report_x86_ports_func() {
  macports_available_func || return 0
  for p in $(port echo active); do
    if [ -n "$(report_x86_only_files_for_port_fast "$p")" ]; then
      echo "$p"
    fi
  done | sort -u
}

# Inspect executable formula files and report binaries containing only x86_64 code.
report_x86_brews_func() {
  local FINDBIN="/usr/bin/find"
  brew list --formula | while read -r pkg; do
    local bin_dir
    bin_dir="$(brew --prefix "$pkg")/bin"
    [[ -d "$bin_dir" ]] || continue
    "$FINDBIN" "$bin_dir" -type f \
      \( -perm -u+x -o -perm -g+x -o -perm -o+x \) | while read -r bin; do
      [[ ! -s "$bin" ]] && continue
      local archs
      archs=$(lipo -archs "$bin" 2>/dev/null || echo "unknown")
      if [[ "$archs" == "x86_64" ]]; then
        echo "$pkg: $(basename "$bin") → $archs"
      fi
    done
  done | sort -u
}

# Scan installed applications with the validated account-specific MacUpdater client.
# Start a detached MacUpdater scan and return immediately.
macup_scan_func() {
  local log_file="${TMPDIR:-/tmp}/refresh_system.macupdater.log"

  checkMacUpdaterApp || return 1

  nohup "${MACUPDTAPP}" scan --quiet \
    >"$log_file" 2>&1 </dev/null &

  local pid=$!

  disown "$pid" 2>/dev/null || true

  printf 'MacUpdater scan started in background (PID %d).\n' "$pid"
  printf 'Log: %s\n' "$log_file"
}

# List filtered MacUpdater results while omitting the scan-date line.
macup_list_func() {
  checkMacUpdaterApp || return 1

  local current_color=$'\033[1;36m'
  local pending_color=$'\033[1;33m'
  local reset=$'\033[0m'

  # shellcheck disable=SC2086
  "${MACUPDTAPP}" list ${MACUPDTAPPOPTS} |
    awk 'NF && $0 !~ /^Last Scan Date[[:space:]]*:/' |
    sort --ignore-case |
    while IFS= read -r line; do
      if [[ $line =~ ^(.*)\ (v[^[:space:]]+)\ \(Update\ to\ (v[^[:space:]]+)\ pending\)$ ]]; then
        printf '%s %s%s%s (Update to %s%s%s pending)\n' \
          "${BASH_REMATCH[1]}" \
          "$current_color" "${BASH_REMATCH[2]}" "$reset" \
          "$pending_color" "${BASH_REMATCH[3]}" "$reset"
      else
        printf '%s\n' "$line"
      fi
    done
}

# Describe non-alias Desktop entries and restore the caller’s nullglob setting.
userDesktopNotAliases_func() {
  local _nullglob_state
  if shopt -q nullglob; then _nullglob_state=-s; else _nullglob_state=-u; fi
  shopt -s nullglob
  for i in ~/Desktop/*; do
    out=$(file --brief -- "$i")
    if [[ "$out" != "MacOS Alias file" ]]; then
      printf "\033[1;36m%-30s\033[0m → \033[1;33m%s\033[0m\n" "$(basename -- "$i")" "$out"
    fi
  done
  shopt "$_nullglob_state" nullglob
}

# Export Python package inventories under a validated Dropbox root; return failure if unavailable.
pip_backup_func() {
  if ! DROPBOX_PATH=$(get_dropbox_path); then
    printf "${bldbrw}Skipped:${txtrst} Dropbox is not available on this system. Skipping pip package list backup.\n" >&2
    # A direct run fails honestly; run_soft_step still lets batch backups continue.
    return 1
  fi
  ENV_SUFFIX=$([[ "$LOGNAME" == "$ENVOFFICE" ]] && echo "office" || echo "home")
  PATH_PREFIX="${DROPBOX_PATH}/${DROPBOX_CONFINFO_RELATIVE}"
  PIP_OUTPUT="${PATH_PREFIX}/pipCompleteList_${ENV_SUFFIX}.txt"

  local pip_cmd=""
  if command -v pip >/dev/null 2>&1; then
    pip_cmd="pip"
  elif command -v pip3 >/dev/null 2>&1; then
    pip_cmd="pip3"
  elif command -v pipx >/dev/null 2>&1; then
    printf "${bldbrw}Note:${txtrst} pip not found; falling back to pipx per-venv freeze.\n"
    # Work relative to an existing root so mkdir can never recreate Dropbox itself.
    (cd -- "$DROPBOX_PATH" && mkdir -p -- "$DROPBOX_CONFINFO_RELATIVE") || return 1
    local pipx_home="${PIPX_HOME:-$HOME/.local/pipx}"
    local venvs_dir="${pipx_home}/venvs"
    if [[ ! -d "$venvs_dir" ]]; then
      fatal "pipx venvs directory not found: ${venvs_dir}"
    fi
    {
      for venv_pip in "$venvs_dir"/*/bin/pip; do
        [[ -x "$venv_pip" ]] || continue
        "$venv_pip" freeze 2>/dev/null
      done
    } | sort -u > "$PIP_OUTPUT" || return 1
    printf "✔︎ List saved to (via pipx): ${bldgrn}%s${txtrst}\n" "$PIP_OUTPUT"
    return 0
  else
    fatal "Neither pip, pip3, nor pipx is installed or in \$PATH."
  fi

  echo "Backing up current pip package list..."
  # Work relative to an existing root so mkdir can never recreate Dropbox itself.
  (cd -- "$DROPBOX_PATH" && mkdir -p -- "$DROPBOX_CONFINFO_RELATIVE") || return 1
  "$pip_cmd" freeze > "$PIP_OUTPUT" || return 1
  printf "✔︎ List saved to: ${bldgrn}%s${txtrst}\n" "$PIP_OUTPUT"
}

# Warn about root privileges and ask mdutil to rebuild the startup-volume index.
rebuild_spotlight_func() {
  warningRootDisplay
  sudo mdutil -E /
}

# Update TeX Live with sudo when installed; preserve the clean skip when tlmgr is absent.
texlive_update_func() {
  if ! command -v tlmgr >/dev/null 2>&1; then
    printf "\n${bldbrw}Warning:${txtrst} tlmgr not found. MacTeX may not be installed.\n"
    return 0
  fi
  warningRootDisplay
  sudo tlmgr update --self --all || fatal "TeX Live update failed."
}

# Invoke the privileged MacPorts update helper, skipping an absent MacPorts installation.
ports_update_func() {
  macports_available_func || return 0
  checkTools ports-update.sh
  warningRootDisplay
  sudo ports-update.sh APPLY
}

# Inventory selection is a second, action-specific interaction. --run must still
# reject it; cancellation is translated to a clean exit by its action handler.
gist_sync_status_func() {
  local gist_choice
  local -a gist_cmd

  checkTools gist-sync

  if [[ "$NON_INTERACTIVE" == "1" ]]; then
    fatal "gist-sync_status requires an interactive inventory mode selection."
  fi

  printf "\n${bldblu}Gists inventory mode${txtrst}\n"
  printf "  1) Full inventory, including synchronized scripts\n"
  printf "  2) Only scripts requiring attention, excluding synchronized scripts\n"
  printf "\n"
  read -r -p "Choose inventory mode [1-2, q to cancel]: " gist_choice || return 130

  case "$gist_choice" in
    1) gist_cmd=(gist-sync status --full) ;;
    2) gist_cmd=(gist-sync status --full --exclude-synced) ;;
    q|Q|"") return 130 ;;
    *) fatal "Invalid inventory mode selection. Exiting." ;;
  esac

  "${gist_cmd[@]}"
  return $?
}

# Office limits refresh to configured repos; Home also discovers repositories.
git_fetch_func() {
  checkTools git_refresh.sh
  if [[ "${LOGNAME}" == "${ENVOFFICE}" ]]; then
    git_refresh.sh --skip --verbose
  elif [[ "${LOGNAME}" == "${ENVHOME}" ]]; then
    git_refresh.sh --skip --discover -v
  else
    echo "Unknown environment: $LOGNAME"
    return 1
  fi
}

# Office sorts in place by default; Home collects from Desktop into Pictures.
# Explicit SCREEN_* overrides and filename-date/stat fallback must remain intact.
tidy_screenshots_func() {
  [[ -n "${SCREENSHOTSDIR:-}" ]] || envScreenshotsDir || {
    printf "\n${bldred}Error:${txtrst} Could not resolve a valid SCREENSHOTSDIR.\n" >&2
    return 4
  }
  local _src_default
  [[ "$LOGNAME" == "$ENVOFFICE" ]] && _src_default="$SCREENSHOTSDIR" || _src_default="$HOME/Desktop"
  local SCREEN_SRC="${SCREEN_SRC:-$_src_default}"
  local SCREEN_DST="${SCREEN_DST:-$SCREENSHOTSDIR}"

  [[ -d "$SCREEN_DST" ]] || {
    printf "\n${bldred}Error:${txtrst} Target directory %s not found.\n" "$SCREEN_DST" >&2
    return 5
  }

  local -a exts=(png jpg heic)
  if [[ -n "${SCREEN_EXTS:-}" ]]; then
    IFS=' ' read -r -a exts <<< "$SCREEN_EXTS"
  fi

  local _nullglob_state
  if shopt -q nullglob; then _nullglob_state=-s; else _nullglob_state=-u; fi
  shopt -s nullglob

  local seen=0 moved=0

  for ext in "${exts[@]}"; do
    for f in "$SCREEN_SRC"/Capture*cran*."$ext" "$SCREEN_SRC"/Screenshot*."$ext"; do
      [ -e "$f" ] || continue
      ((seen++))

      local base d y m dst
      base="${f##*/}"
      if [[ "$base" =~ ([0-9]{4}-[0-9]{2}-[0-9]{2}) ]]; then
        d="${BASH_REMATCH[1]}"
      else
        d=$(/usr/bin/stat -f '%Sm' -t '%Y-%m-%d' -- "$f") || {
          printf "\n${bldred}Error:${txtrst} Failed to read timestamp via stat: %q\n" "$f" >&2
          continue
        }
      fi

      y=${d:0:4}; m=${d:5:2}
      dst="$SCREEN_DST/$y/$y-$m/$d"

      mkdir -p -- "$dst"
      if mv -vn -- "$f" "$dst/"; then
        ((moved++))
      fi
    done
  done
  printf 'Found screenshots: %d | moved: %d\n' "$seen" "$moved"
  shopt "$_nullglob_state" nullglob
}

# Resolve the configured Mackup storage engine and reject an unavailable storage directory.
resolve_mackup_storage() {
  local cfg="$HOME/.mackup.cfg"
  local engine="dropbox"
  local custom_path=""

  if [[ -f "$cfg" ]]; then
    local in_storage=0
    while IFS= read -r line; do
      line="${line%%#*}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
      [[ -z "$line" ]] && continue
      if [[ "$line" =~ ^\[(.+)\]$ ]]; then
        [[ "${BASH_REMATCH[1]}" == "storage" ]] && in_storage=1 || in_storage=0
        continue
      fi
      if [[ "$in_storage" -eq 1 && "$line" =~ ^([^=]+)=(.*)$ ]]; then
        local key val
        key="${BASH_REMATCH[1]}"
        key="${key%"${key##*[![:space:]]}"}"
        val="${BASH_REMATCH[2]}"
        val="${val#"${val%%[![:space:]]*}"}"
        case "$key" in
          engine) engine="$val" ;;
          path)   custom_path="$val" ;;
        esac
      fi
    done < "$cfg"
  fi

  local storage_dir=""
  case "$engine" in
    dropbox) storage_dir=$(get_dropbox_path) ;;
    icloud) storage_dir="$HOME/Library/Mobile Documents/com~apple~CloudDocs" ;;
    copy) storage_dir="$HOME/Copy" ;;
    file_system)
      if [[ -n "$custom_path" ]]; then
        storage_dir="$custom_path"
      else
        printf "${bldred}Error:${txtrst} mackup engine is 'file_system' but no path is set in ~/.mackup.cfg\n" >&2
        return 1
      fi
      ;;
    *)
      printf "${bldred}Error:${txtrst} Unknown mackup storage engine: '%s'\n" "$engine" >&2
      return 1
      ;;
  esac

  if [[ ! -d "$storage_dir" ]]; then
    printf "${bldbrw}Skipped:${txtrst} mackup storage (%s) is not mounted or reachable: %s\n" "$engine" "$storage_dir"
    return 1
  fi
  printf '%s\n' "$storage_dir"
}

# Skip when iTerm2 can overwrite preferences or the configured storage is offline.
dotfiles_func() {
  checkTools mackup

  if [[ "$TERM_PROGRAM" == "iTerm.app" ]] || pgrep -q iTerm2; then
    printf "${bldbrw}Skipped:${txtrst} iTerm2 is running. Please quit it before running dotfiles backup.\n"
    return 0
  fi
  resolve_mackup_storage > /dev/null || return 0
  mackup backup -f
}

# Batch steps report failures and continue; do not substitute the fatal run_step.
run_soft_step() {
  local choice="$1"; shift
  printSelectedOption "$choice"
  if ! "$@"; then
    echo -e "⚠️ ${bldred}Error:${txtrst} Step [$choice] failed"
  fi
}

# Batch membership/order are deliberate, including direct helper calls rather
# than individual-action wrappers. Both inventory helpers require existing destinations
# and do not create a Dropbox root; keep their local Office destinations supported.
run_all_backups_func() {
  run_soft_step  1 dotfiles_func                 || echo "[dotfiles_func] failed"
  run_soft_step  9 ports-infoBackup.sh           || echo "[ports-infoBackup.sh] failed"
  run_soft_step 13 brew_conf_export.sh           || echo "[brew_conf_export.sh] failed"
  run_soft_step 20 pip_backup_func               || echo "[pip_backup_func] failed"
}

# Run the established update sequence, including TeX Live, without aborting on soft failures.
run_all_updates_func() {
  run_soft_step  4 softwareupdate --list         || echo "[softwareupdate] failed"
  run_soft_step  5 mas upgrade                   || echo "[mas upgrade] failed"
  run_soft_step  8 ports_update_func             || echo "[ports-update.sh APPLY] failed"
  texlive_update_func                            || echo "[tlmgr update] function failed"
  run_soft_step 12 brew-update.sh                || echo "[brew-update.sh] failed"
  run_soft_step 16 nix_upgrade_func              || echo "[nix_upgrade_func] failed"
}

# Run the three reference comparisons in their established order with soft failures.
run_all_comparisons_func() {
  run_soft_step  2 bashrc_resync.sh              || echo "[bashrc_resync.sh] failed"
  run_soft_step 14 compare_brew_home_office.sh   || echo "[compare_brew_home_office.sh] failed"
  run_soft_step 10 compare_ports_home_office.sh  || echo "[compare_ports_home_office.sh] failed"
}

# Display the selection, execute one step, and abort on failure before reporting completion.
run_step() {
  local choice="$1"; shift
  printSelectedOption "$choice"
  "$@" || {
    fatal "Command failed. Aborting."
  }
  infoFinished
}

# Validate an external helper and execute it with sudo using the standard fatal-step semantics.
privileged_run_step() {
  local choice="$1"; shift
  local script="$1"; shift
  printSelectedOption "$choice"
  checkTools "$script"
  warningRootDisplay
  sudo "$script" "$@" || {
    fatal "Command failed. Aborting."
  }
  infoFinished
}

# The header is also the dependency helper manifest; preserve its parseable format.
required_gist_scripts() {
  awk '
    /^#  • / && /https:\/\/gist\.github\.com\/dzogrim\// {
      name = $0
      sub(/^#  •[[:space:]]*/, "", name)
      sub(/:.*/, "", name)

      gist = $0
      sub(/^.*https:\/\/gist\.github\.com\/dzogrim\//, "", gist)
      sub(/[[:space:]#?].*$/, "", gist)
      sub(/\/$/, "", gist)

      if (name != "" && gist ~ /^[[:alnum:]]+$/)
        printf "%s\t%s\n", name, gist
    }
  ' "$0"
}

# Select the AdminHelpers installation path for Home or Office; reject unknown accounts.
resolve_script_install_dir() {
  case "$LOGNAME" in
    "$ADM_SHELL_USER_PERSO") printf '%s\n' "$ADM_SHELL_SCPT_PERSO" ;;
    "$ADM_SHELL_USER_PROv1") printf '%s\n' "$ADM_SHELL_SCPT_PROv1" ;;
    *) printf 'Error: unsupported account: %s\n' "$LOGNAME" >&2; return 1 ;;
  esac
}

# Report availability of each header-declared helper and fail if any are missing.
check_gist_script_dependencies() {
  local script_name gist_id
  local -a missing=()

  while IFS=$'\t' read -r script_name gist_id; do
    if ! command -v "$script_name" >/dev/null 2>&1; then
      missing+=("$script_name")
      printf 'Missing: %s\n' "$script_name"
    else
      printf 'Found:   %-30s %s\n' "$script_name" "$(command -v "$script_name")"
    fi
  done < <(required_gist_scripts)

  if (( ${#missing[@]} > 0 )); then
    printf '\nMissing %d required script(s).\n' "${#missing[@]}" >&2
    return 1
  fi
  printf '\nAll declared Gist scripts are available in PATH.\n'
}

# Install missing Gist helpers into the account’s configured directory and report failures.
install_gist_script_dependencies() {
  local install_dir temp_dir
  local script_name gist_id source_file
  local installed=0 failed=0

  install_dir=$(resolve_script_install_dir) || return 1
  [[ -n "$install_dir" ]] || { printf 'Error: resolved installation directory is empty.\n' >&2; return 1; }
  # AdminHelpers may put scripts in Dropbox. Do not let dependency installation
  # fabricate the standard Dropbox root either; unrelated local paths stay supported.
  if [[ "$install_dir" == "$DROPBOX_DEFAULT_ROOT" || "$install_dir" == "$DROPBOX_DEFAULT_ROOT/"* ]]; then
    local relative_dir=.
    [[ "$install_dir" == "$DROPBOX_DEFAULT_ROOT" ]] || relative_dir=${install_dir#"$DROPBOX_DEFAULT_ROOT/"}
    (cd -- "$DROPBOX_DEFAULT_ROOT" && mkdir -p -- "$relative_dir") || {
      printf 'Error: Dropbox is unavailable or cannot create directory: %s\n' "$install_dir" >&2
      return 1
    }
  else
    mkdir -p "$install_dir" || { printf 'Error: cannot create directory: %s\n' "$install_dir" >&2; return 1; }
  fi
  [[ -w "$install_dir" ]] || { printf 'Error: directory is not writable: %s\n' "$install_dir" >&2; return 1; }

  while IFS=$'\t' read -r script_name gist_id; do
    if command -v "$script_name" >/dev/null 2>&1; then
      printf 'Already installed: %-30s %s\n' "$script_name" "$(command -v "$script_name")"
      continue
    fi

    temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/refresh-gist.XXXXXX") || return 1
    printf 'Installing %s from Gist %s...\n' "$script_name" "$gist_id"

    if ! gh gist clone "$gist_id" "$temp_dir" >/dev/null 2>&1; then
      printf 'Error: failed to clone Gist %s.\n' "$gist_id" >&2
      rm -rf "$temp_dir"
      failed=$((failed + 1))
      continue
    fi

    source_file="$temp_dir/$script_name"
    if [[ ! -f "$source_file" ]]; then
      printf 'Error: %s is not present in Gist %s.\n' "$script_name" "$gist_id" >&2
      rm -rf "$temp_dir"
      failed=$((failed + 1))
      continue
    fi

    if install -m 0755 "$source_file" "$install_dir/$script_name"; then
      printf 'Installed: %s\n' "$install_dir/$script_name"
      installed=$((installed + 1))
    else
      printf 'Error: failed to install %s.\n' "$script_name" >&2
      failed=$((failed + 1))
    fi
    rm -rf "$temp_dir"
  done < <(required_gist_scripts)

  printf '\nInstalled: %d; failed: %d\n' "$installed" "$failed"

  if [[ ":$PATH:" != *":$install_dir:"* ]]; then
    printf 'Warning: installation directory is not currently in PATH: %s\n' "$install_dir" >&2
    failed=$((failed + 1))
  fi
  (( failed == 0 ))
}

# ============================================================================
#  Action Registry
# ============================================================================
declare -a ACTION_IDS=()
declare -A ACTION_LABEL=()
declare -A ACTION_CATEGORY=()
declare -A ACTION_HANDLER=()

# All actions must be declared through register_action(). Do not manually
# populate the registry arrays: implement a handler, then register it once.
register_action() {
  local id=${1:-} category=${2:-} label=${3:-} handler=${4:-}
  [[ "$id" =~ ^[0-9]+$ ]] || fatal "Invalid action ID: $id"
  [[ -z ${ACTION_HANDLER[$id]+x} ]] || fatal "Duplicate action ID: $id"
  [[ -n "$category" ]] || fatal "Missing category for action $id"
  [[ -n "$label" ]] || fatal "Missing label for action $id"
  [[ -n "$handler" ]] || fatal "Missing handler for action $id"
  [[ "$category$label" != *$'\t'* && "$category$label" != *$'\n'* && "$category$label" != *$'\r'* ]] ||
    fatal "Action $id: category and label must not contain tabs or line breaks"
  declare -F "$handler" >/dev/null || fatal "Action $id: handler '$handler' is not defined"
  ACTION_IDS+=("$id")
  ACTION_CATEGORY["$id"]="$category"
  ACTION_LABEL["$id"]="$label"
  ACTION_HANDLER["$id"]="$handler"
}

# Categories are display metadata only; registration order and numeric IDs stay stable.
# Terminal-specific category labels.
if [[ ${TERM_PROGRAM:-} == "Apple_Terminal" ]]; then
  readonly CATEGORY_SYNCRO="↻  Sync & Config"
  readonly CATEGORY_SYSTEM="⬆  System updates"
  readonly CATEGORY_MACPORTS="◈  MacPorts"
  readonly CATEGORY_HOMEBREW="◆  Homebrew"
  readonly CATEGORY_NIXOS="❄  Nix & NixOS"
  readonly CATEGORY_PYTHON="λ  Python env"
  readonly CATEGORY_MAINT="⚙  Maintenance"
  readonly CATEGORY_BATCH="»  Batch actions"
else
  readonly CATEGORY_BATCH="🚀 Batch actions"
  readonly CATEGORY_HOMEBREW="🍺 Homebrew"
  readonly CATEGORY_MACPORTS="📦 MacPorts"
  readonly CATEGORY_MAINT="🧰 Maintenance"
  readonly CATEGORY_NIXOS="❄️ Nix & NixOS"
  readonly CATEGORY_PYTHON="🐍 Python env"
  readonly CATEGORY_SYNCRO="🔄 Sync & Config"
  readonly CATEGORY_SYSTEM="🖥️ System updates"
fi

# Register the stable action inventory once in its established category and menu order.
initialize_action_registry() {
  register_action  1 "$CATEGORY_SYNCRO"   "Sync dotfiles & prefs to Dropbox (mackup)"         action_dotfiles
  register_action  2 "$CATEGORY_SYNCRO"   "Compare ~/.bashrc.d and other config with refs"    action_bashrc_compare
  register_action  3 "$CATEGORY_SYNCRO"   "Update local Git repos (fast mode)"                action_git_fetch
  register_action  4 "$CATEGORY_SYSTEM"   "Check macOS system updates (Apple)"                action_macos_updates
  register_action  5 "$CATEGORY_SYSTEM"   "Update Mac App Store apps (mas)"                   action_app_store_update
  register_action  6 "$CATEGORY_SYSTEM"   "MacUpdater: Scan apps for updates (1st)"           action_macup_scan
  register_action  7 "$CATEGORY_SYSTEM"   "List available MacUpdater updates (2nd)"           action_macup_list
  register_action  8 "$CATEGORY_MACPORTS" "Update MacPorts packages"                          action_ports_update
  register_action  9 "$CATEGORY_MACPORTS" "Backup MacPorts config to Dropbox"                 action_backup_ports
  register_action 10 "$CATEGORY_MACPORTS" "Compare MacPorts with reference env"               action_compare_ports
  register_action 11 "$CATEGORY_MACPORTS" "List MacPorts with x86_64 binaries"                action_report_x86_ports
  register_action 12 "$CATEGORY_HOMEBREW" "Update Homebrew packages"                          action_brew_update
  register_action 13 "$CATEGORY_HOMEBREW" "Backup Brew bundle to Dropbox"                     action_backup_brew
  register_action 14 "$CATEGORY_HOMEBREW" "Compare Brew with reference env"                   action_compare_brew
  register_action 15 "$CATEGORY_HOMEBREW" "List Brew formulae with x86_64 binaries"           action_report_x86_brews
  register_action 16 "$CATEGORY_NIXOS"    "Upgrade Nix environment"                           action_nix_upgrade
  register_action 17 "$CATEGORY_NIXOS"    "Activate Home Manager profile"                     action_nix_activate
  register_action 18 "$CATEGORY_NIXOS"    "Rollback Home Manager config"                      action_nix_rollback
  register_action 19 "$CATEGORY_PYTHON"   "Set Python ${PYVERS_H} as default"                 action_python_version
  register_action 20 "$CATEGORY_PYTHON"   "Export pip freeze list to Dropbox"                 action_pip_backup
  register_action 21 "$CATEGORY_MAINT"    "Rebuild Spotlight index"                           action_spotlight
  register_action 22 "$CATEGORY_MAINT"    "Reset Spotlight position (UI)"                     action_spotlight_reset
  register_action 23 "$CATEGORY_MAINT"    "Remove Microsoft AutoUpdate (MAU)"                 action_remove_msupdt
  register_action 24 "$CATEGORY_MAINT"    "Check SSL certificate expirations"                 action_ssl_checks
  register_action 25 "$CATEGORY_MAINT"    "Sanitize shell configuration"                      action_sanitize_shell_checks
  register_action 26 "$CATEGORY_MAINT"    "Ensure Desktop contains only aliases"              action_desktop_non_aliases
  register_action 27 "$CATEGORY_MAINT"    "Tidy macOS screenshots"                            action_tidy_screenshots
  register_action 28 "$CATEGORY_MAINT"    "Update TeX Live packages (tlmgr)"                  action_texlive_update
  register_action 29 "$CATEGORY_MAINT"    "Build gists inventory (gist-sync)"                 action_gist_sync_status
  register_action 30 "$CATEGORY_MAINT"    "Install or Upgrade 'Free Claude Code'"             action_fcc_online_upgrade
  register_action 97 "$CATEGORY_BATCH"    "Run all comparison tasks (dotfiles, Brew, Ports)"  action_run_all_comparisons
  register_action 98 "$CATEGORY_BATCH"    "Run all update tasks (Apple, Ports, Brew, Nix)"    action_run_all_updates
  register_action 99 "$CATEGORY_BATCH"    "Run all backup tasks (dotfiles, pip, Brew, Ports)" action_run_all_backups
}

# ============================================================================
#  Menu Architecture
# ============================================================================

# Display the registry label for a selected ID or report missing selection metadata.
printSelectedOption() {
  local choice_num=$1
  local label="${ACTION_LABEL[$choice_num]}"
  if [[ -n "$label" ]]; then
    printf "\n${bldblu}Selected Option${txtrst}: ${bldcya}%s${txtrst}\n" "$label"
  else
    printf "\n${bldred}Error:${txtrst} Selected option not found in registry.\n"
  fi
}

# Audit registry integrity, structured-menu metadata and the configured default action.
debug_validate_choice_map() {
  local id handler field key
  local errors=0 duplicates=0 missing_metadata=0 missing_handlers=0 validated=0
  local -A seen=()
  for id in "${ACTION_IDS[@]}"; do
    if [[ ! "$id" =~ ^[0-9]+$ ]]; then
      printf 'Invalid action ID: %s\n' "$id" >&2
      errors=$((errors + 1))
      continue
    fi
    if [[ -n ${seen[$id]+x} ]]; then
      printf 'Duplicate action ID: %s\n' "$id" >&2
      duplicates=$((duplicates + 1))
      errors=$((errors + 1))
    fi
    seen["$id"]=1
    for field in ACTION_CATEGORY ACTION_LABEL ACTION_HANDLER; do
      local -n metadata="$field"
      if [[ -z ${metadata[$id]:-} ]]; then
        printf 'Action %s: missing %s metadata\n' "$id" "$field" >&2
        missing_metadata=$((missing_metadata + 1))
        errors=$((errors + 1))
      fi
    done
    if [[ "${ACTION_CATEGORY[$id]:-}${ACTION_LABEL[$id]:-}" == *$'\t'* ||
          "${ACTION_CATEGORY[$id]:-}${ACTION_LABEL[$id]:-}" == *$'\n'* ||
          "${ACTION_CATEGORY[$id]:-}${ACTION_LABEL[$id]:-}" == *$'\r'* ]]; then
      printf 'Action %s: category or label contains a menu record separator\n' "$id" >&2
      errors=$((errors + 1))
    fi
    handler=${ACTION_HANDLER[$id]:-}
    if [[ -z "$handler" ]] || ! declare -F "$handler" >/dev/null; then
      printf "Action %s: handler '%s' is not defined\n" "$id" "$handler" >&2
      missing_handlers=$((missing_handlers + 1))
      errors=$((errors + 1))
    else
      validated=$((validated + 1))
    fi
  done
  for field in ACTION_CATEGORY ACTION_LABEL ACTION_HANDLER; do
    local -n metadata="$field"
    for key in "${!metadata[@]}"; do
      if [[ -z ${seen[$key]+x} ]]; then
        printf 'Orphaned %s entry: action %s\n' "$field" "$key" >&2
        errors=$((errors + 1))
      fi
    done
  done
  default_menu_position >/dev/null || errors=$((errors + 1))
  if (( errors > 0 )); then
    printf 'Action registry validation: FAILED (%d errors)\n' "$errors" >&2
    return 1
  fi
  printf 'Action registry validation: OK\nRegistered actions: %d\nHandlers validated: %d\nDuplicate IDs: %d\nMissing metadata: %d\nMissing handlers: %d\n' \
    "${#ACTION_IDS[@]}" "$validated" "$duplicates" "$missing_metadata" "$missing_handlers"
}

# Emit canonical ID/category/label TSV records in stable registration order.
# Tabs/newlines in metadata are rejected by registration and the integrity audit.
build_menu_records() {
  local id
  for id in "${ACTION_IDS[@]}"; do
    printf '%s\t%s\t%s\n' "$id" "${ACTION_CATEGORY[$id]}" "${ACTION_LABEL[$id]}"
  done
}

# Format a record for display only; neither selector extracts identity from this text.
format_menu_label() {
  # Each chosen emoji occupies two terminal cells; pad only the ASCII category text.
  # Bash printf measures UTF-8 bytes, so padding the complete category misaligns rows.
  local icon=${2%% *} category_text=${2#* }
  printf '%s %-22s → [%02d] %s' "$icon" "$category_text" "$1" "$3"
}

# Resolve the configured default to its one-based menu position without reordering records.
default_menu_position() {
  local id position=0
  if [[ "$DEFAULT_SELECTION" =~ ^[0-9]+$ && -n ${ACTION_HANDLER[$DEFAULT_SELECTION]:-} ]] &&
      declare -F "${ACTION_HANDLER[$DEFAULT_SELECTION]}" >/dev/null; then
    for id in "${ACTION_IDS[@]}"; do
      position=$((position + 1))
      if [[ "$id" == "$DEFAULT_SELECTION" ]]; then
        printf '%d\n' "$position"
        return 0
      fi
    done
  fi
  printf 'Invalid default action ID: %s (internal menu configuration error)\n' "$DEFAULT_SELECTION" >&2
  return 1
}

# Build gum’s environment header from the existing login/account model and hostname.
build_menu_header() {
  local environment=Unknown
  if [[ "$LOGNAME" == "$ENVHOME" ]]; then
    environment=Home
  elif [[ "$LOGNAME" == "$ENVOFFICE" ]]; then
    environment=Office
  fi
  printf 'macOS Maintenance — %s — %s' "$(hostname -s)" "$environment"
}

# Bound fzf with a timed pipe read, not a background timer. The subshell owns only
# this fzf PID, and its EXIT trap terminates/reaps it and closes the pipe on every exit.
# Status 124 means timeout; other fzf statuses remain available to the caller.
run_fzf_with_timeout() (
  local result_fd selector_pid="" selected_record="" read_status=0 selector_status=0
  trap 'if [[ -n "$selector_pid" ]]; then
          kill -TERM "$selector_pid" 2>/dev/null
          wait "$selector_pid" 2>/dev/null
        fi
        [[ -z ${result_fd:-} ]] || exec {result_fd}<&-' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  exec {result_fd}< <(exec fzf "$@")
  selector_pid=$!
  IFS= read -r -t "$TIMEOUT_SEC" -u "$result_fd" selected_record || read_status=$?
  (( read_status <= 128 )) || return 124
  wait "$selector_pid" || selector_status=$?
  selector_pid=""
  (( selector_status == 0 )) || return "$selector_status"
  [[ "$read_status" -eq 0 && -n "$selected_record" ]] || return 130
  printf '%s\n' "$selected_record"
)

# Present the styled fzf menu; retain structured IDs, shared timeout and default focus.
select_action_fzf() {
  local selected_record id category label default_position selector_status=0
  default_position=$(default_menu_position) || return 1
  # The guarded assignment captures cancellation/timeout even with errexit enabled.
  # Keep the caller's shell flags intact rather than unconditionally setting -e.
  # Preview geometry/key bindings are reserved; no preview command runs any code.
  selected_record=$(
    while IFS=$'\t' read -r id category label; do
      printf '%s\t' "$id"
      format_menu_label "$id" "$category" "$label"
      printf '\n'
    done < <(build_menu_records) | run_fzf_with_timeout \
      --delimiter=$'\t' \
      --with-nth=2.. \
      --bind="load:pos($default_position)" \
      --header="😎 Acting as ${LOGNAME} on $(hostname -s)" \
      --height=55% \
      --layout=reverse \
      --info=inline \
      --pointer="▶" \
      --marker="✓" \
      --preview-window=right:60%:wrap:hidden \
      --ansi \
      --cycle \
      --border \
      --color=bg+:#1e1e2e,bg:#181825,fg:#cdd6f4,hl:#f38ba8,fg+:#cdd6f4,hl+:#f38ba8,info:#cba6f7,prompt:#f9e2af,pointer:#f5e0dc,marker:#a6e3a1,spinner:#f5e0dc,header:#89b4fa \
      --bind="ctrl-j:down,ctrl-k:up" \
      --bind="ctrl-d:preview-page-down,ctrl-u:preview-page-up" \
      --bind="ctrl-p:toggle-preview" \
      --bind="ctrl-x:abort" \
      --exit-0 \
      --no-multi \
      --prompt="Maintenance > "
  ) || selector_status=$?
  # fzf's no-match result remains a clean cancellation, never a default acceptance.
  [[ "$selector_status" -ne 1 ]] || return 130
  [[ "$selector_status" -eq 0 ]] || return "$selector_status"
  [[ -n "$selected_record" ]] || return 130
  [[ "$selected_record" == *$'\t'* ]] || return 1
  printf '%s\n' "${selected_record%%$'\t'*}"
}

# Present gum with native timeout and shared default focus, preserving structured ID values.
select_action_gum() {
  local id category label selected_id default_label="" display_label selector_status=0
  local -a choices=()
  default_menu_position >/dev/null || return 1
  while IFS=$'\t' read -r id category label; do
    display_label=$(format_menu_label "$id" "$category" "$label")
    choices+=("$display_label"$'\t'"$id")
    # gum's --selected expects the display label; obtain it by structured ID comparison.
    [[ "$id" != "$DEFAULT_SELECTION" ]] || default_label=$display_label
  done < <(build_menu_records)
  selected_id=$(gum choose \
    --height=20 \
    --header="$(build_menu_header)" \
    --limit=1 \
    --timeout="${TIMEOUT_SEC}s" \
    --selected="$default_label" \
    --label-delimiter=$'\t' \
    "${choices[@]}") || selector_status=$?
  # Discard all output on timeout, even if gum includes its currently focused value.
  [[ "$selector_status" -ne 124 ]] || return 124
  [[ "$selector_status" -eq 0 ]] || return 130
  [[ -n "$selected_id" ]] || return 130
  printf '%s\n' "$selected_id"
}

# Parse CLI intent once, defaulting to fzf unless gum is explicitly requested.
parse_args() {
  MODE=interactive
  MENU_ENGINE=fzf
  CHOICE=""
  NON_INTERACTIVE=0
  [[ $# -gt 0 ]] || return 0

  case "$1" in
    --run)
      [[ $# -eq 2 && "$2" =~ ^[0-9]+$ ]] || fatal "Missing or invalid argument for --run."
      [[ -n ${ACTION_LABEL[$2]:-} ]] || fatal "Invalid option ID."
      MODE=run
      CHOICE="$2"
      NON_INTERACTIVE=1
      ;;
    --list)
      [[ $# -eq 1 ]] || fatal "Invalid arguments for --list."
      MODE=list
      ;;
    -h|--help|--debug-choices|--check-deps-scpt|--install-deps-scpt|--gum|--fzf)
      [[ $# -eq 1 ]] || fatal "$1 takes no argument."
      case "$1" in
        -h|--help) MODE=help ;;
        --debug-choices) MODE=debug_choices ;;
        --check-deps-scpt) MODE=check_deps ;;
        --install-deps-scpt) MODE=install_deps ;;
        --gum) MENU_ENGINE=gum ;;
        --fzf) MENU_ENGINE=fzf ;;
      esac
      ;;
    *) fatal "Unknown or excessive arguments." ;;
  esac
}

# Handlers retain the original step wrappers, prompts and exit semantics.
# Back up dotfiles through the standard step wrapper and existing Mackup safety checks.
action_dotfiles() {
  local choice="$1"
  run_step "$choice" dotfiles_func
}

# Run the configuration comparison through the standard step wrapper.
action_bashrc_compare() {
  local choice="$1"
  run_step "$choice" bashrc_resync.sh
}

# Run the local Git refresh through the standard step wrapper.
action_git_fetch() {
  local choice="$1"
  run_step "$choice" git_fetch_func
}

# Run the macOS update check through the standard step wrapper.
action_macos_updates() {
  local choice="$1"
  run_step "$choice" softwareupdate --list
}

# Run the App Store upgrade through the standard step wrapper.
action_app_store_update() {
  local choice="$1"
  run_step "$choice" mas upgrade
}

# Run the MacUpdater scan through the standard step wrapper.
action_macup_scan() {
  local choice="$1"
  run_step "$choice" macup_scan_func
}

# Run the MacUpdater listing through the standard step wrapper.
action_macup_list() {
  local choice="$1"
  run_step "$choice" macup_list_func
}

# Run the MacPorts update through the standard step wrapper.
action_ports_update() {
  local choice="$1"
  run_step "$choice" ports_update_func
}

# Run the MacPorts inventory backup through the standard step wrapper.
action_backup_ports() {
  local choice="$1"
  run_step "$choice" backup_ports_func
}

# Run the MacPorts reference comparison through the standard step wrapper.
action_compare_ports() {
  local choice="$1"
  run_step "$choice" compare_ports_func
}

# Run the MacPorts architecture report through the standard step wrapper.
action_report_x86_ports() {
  local choice="$1"
  run_step "$choice" report_x86_ports_func
}

# Run the Homebrew update through the standard step wrapper.
action_brew_update() {
  local choice="$1"
  run_step "$choice" brew-update.sh
}

# Run the Brew bundle backup through the standard step wrapper.
action_backup_brew() {
  local choice="$1"
  # The helper cd's into an existing destination; Office may use local dotfiles.
  run_step "$choice" brew_conf_export.sh
}

# Run the Brew reference comparison through the standard step wrapper.
action_compare_brew() {
  local choice="$1"
  run_step "$choice" compare_brew_home_office.sh
}

# Run the Homebrew architecture report through the standard step wrapper.
action_report_x86_brews() {
  local choice="$1"
  run_step "$choice" report_x86_brews_func
}

# Run the Nix environment upgrade through the standard step wrapper.
action_nix_upgrade() {
  local choice="$1"
  run_step "$choice" nix_upgrade_func
}

# Run the Home Manager activation through the standard step wrapper.
action_nix_activate() {
  local choice="$1"
  run_step "$choice" nix-manager-adm activate
}

# Run the Home Manager rollback through the standard step wrapper.
action_nix_rollback() {
  local choice="$1"
  run_step "$choice" nix-manager-adm rollback
}

# Set the configured Python version through the privileged step wrapper.
action_python_version() {
  local choice="$1"
  privileged_run_step "$choice" set-python-123.sh "${PYVERS}"
}

# Run the Python inventory export through the standard step wrapper.
action_pip_backup() {
  local choice="$1"
  run_step "$choice" pip_backup_func
}

# Run the Spotlight rebuild through the standard step wrapper.
action_spotlight() {
  local choice="$1"
  run_step "$choice" rebuild_spotlight_func
}

# Run the Spotlight position reset through the standard step wrapper.
action_spotlight_reset() {
  local choice="$1"
  run_step "$choice" reset_spotlight_position.sh
}

# Remove Microsoft AutoUpdate through the privileged step wrapper.
action_remove_msupdt() {
  local choice="$1"
  privileged_run_step "$choice" remove-MAU2.sh
}

# Run the SSL certificate check through the standard step wrapper.
action_ssl_checks() {
  local choice="$1"
  run_step "$choice" certs_validity.sh
}

# Run the shell configuration check through the standard step wrapper.
action_sanitize_shell_checks() {
  local choice="$1"
  run_step "$choice" check_env_shell.sh
}

# Run the Desktop alias check through the standard step wrapper.
action_desktop_non_aliases() {
  local choice="$1"
  run_step "$choice" userDesktopNotAliases_func
}

# Run the screenshot tidying through the standard step wrapper.
action_tidy_screenshots() {
  local choice="$1"
  run_step "$choice" tidy_screenshots_func
}

# Run the TeX Live update through the standard step wrapper.
action_texlive_update() {
  local choice="$1"
  run_step "$choice" texlive_update_func
}

# Run Gist inventory selection, translating cancellation and preserving helper failure codes.
action_gist_sync_status() {
  local choice="$1"
  printSelectedOption "$choice"
  gist_sync_status_func
  GIST_SYNC_STATUS=$?
  if [[ "$GIST_SYNC_STATUS" -eq 130 ]]; then
      printf "\n${bldbrw}User aborted.${txtrst} Exiting.\n"
      exit 0
  elif [[ "$GIST_SYNC_STATUS" -ne 0 ]]; then
      printf "\n${bldred}Error:${txtrst} gist-sync status failed with exit code %d.\n" "$GIST_SYNC_STATUS" >&2
      exit "$GIST_SYNC_STATUS"
  fi
  infoFinished
}

# Run the FCC installation or upgrade through the standard step wrapper.
action_fcc_online_upgrade() {
  local choice="$1"
  run_step "$choice" fcc_online_upgrade_func
}

# Run the comparison batch through the standard step wrapper.
action_run_all_comparisons() {
  local choice="$1"
  run_step "$choice" run_all_comparisons_func
}

# Run the update batch through the standard step wrapper.
action_run_all_updates() {
  local choice="$1"
  run_step "$choice" run_all_updates_func
}

# Run the backup batch through the standard step wrapper; individual failures remain soft.
action_run_all_backups() {
  local choice="$1"
  run_step "$choice" run_all_backups_func
}

# ACTION_HANDLER contains real Bash function names. The dispatcher intentionally
# contains no action-specific mapping; every presentation uses this same path.
dispatch_action() {
  local choice="$1"
  local handler="${ACTION_HANDLER[$choice]:-}"
  if [[ -z "$handler" ]]; then
    fatal "Unknown option [ $choice ] selected. This should never happen."
  fi
  declare -F "$handler" >/dev/null ||
    fatal "Action $choice: handler '$handler' is not defined"
  "$handler" "$choice"
}

# Sourcing defines functions/constants only; direct execution keeps the existing lifecycle.
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  return 0
fi

initialize_action_registry
parse_args "$@"

# Metadata inspection requires no AdminHelpers, terminal or maintenance dependencies.
case "$MODE" in
  help) usage ;;
  list)
    echo -e "\nAvailable actions:"
    for id in "${ACTION_IDS[@]}"; do
      printf "  %2d  - %s\n" "$id" "${ACTION_LABEL[$id]}"
    done
    exit 0
    ;;
  debug_choices) debug_validate_choice_map; exit $? ;;
esac

# Dependency inspection needs only PATH and the header; installation also needs
# validated AdminHelpers accounts/paths. Neither path initializes maintenance or UI tools.
case "$MODE" in
  check_deps)
    checkTools awk
    check_gist_script_dependencies
    exit $?
    ;;
  install_deps)
    initialize_admin_environment
    resolve_login_name
    checkTools awk gh git install
    install_gist_script_dependencies
    exit $?
    ;;
esac

# Normal interactive and direct actions retain the complete execution safety checks.
initialize_execution_environment
initChecks
case "$MODE" in
  run)
    echo -e "${bldblu}Running in non-interactive mode:${txtrst} Option $CHOICE"
    ;;
  interactive)
    default_menu_position >/dev/null || fatal "Invalid default menu configuration."
    # Resolve fallback before clearing; an explicit fzf request never probes gum.
    if [[ "$MENU_ENGINE" == gum ]] && ! command -v gum >/dev/null 2>&1; then
      echo -e "${bldbrw}Warning:${txtrst} gum is not installed. Falling back to fzf."
      MENU_ENGINE=fzf
    fi
    [[ "$MENU_ENGINE" != fzf ]] || checkTools fzf
    # Clear only after initialization and selector validation, immediately before the UI.
    clear
    if [[ "$MENU_ENGINE" == gum ]]; then
      CHOICE=$(select_action_gum)
      MENU_EXIT_CODE=$?
    else
      CHOICE=$(select_action_fzf)
      MENU_EXIT_CODE=$?
    fi
    if [[ "$MENU_EXIT_CODE" -eq 124 ]]; then
      printf '\nMenu timed out after %s seconds. Exiting.\n' "$TIMEOUT_SEC"
      exit 0
    fi
    if [[ "$MENU_EXIT_CODE" -eq 130 ]]; then
      printf "\n${bldbrw}User aborted.${txtrst} Exiting.\n"
      exit 0
    fi
    if [[ "$MENU_EXIT_CODE" -ne 0 || ! "$CHOICE" =~ ^[0-9]+$ ]]; then
      fatal "Invalid or non-actionable menu selection. Exiting."
    fi
    [[ -n ${ACTION_HANDLER[$CHOICE]:-} ]] || fatal "Invalid or non-actionable menu selection. Exiting."
    ;;
esac

dispatch_action "$CHOICE"
