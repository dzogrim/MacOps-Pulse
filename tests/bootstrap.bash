#!/usr/bin/env bash
# Install pinned Bats-core locally; never change global packages.
set -euo pipefail
project_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
target="$project_dir/.test-tools/bats-core"
expected=5da66876b8b619235aee1eb3e54954eaca88059b
if [[ ! -d "$target" ]]; then
  mkdir -p -- "$project_dir/.test-tools"
  git clone --depth 1 --branch v1.11.0 https://github.com/bats-core/bats-core.git "$target"
fi
[[ $(git -C "$target" rev-parse HEAD) == "$expected" ]] || {
  printf 'Bats checkout does not match the pinned commit.\n' >&2
  exit 1
}
printf 'Project-local Bats-core v1.11.0 ready.\n'
