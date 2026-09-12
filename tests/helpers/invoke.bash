#!/usr/bin/env bash
# Load definitions without main and invoke the requested real function in isolation.
 # shellcheck source=tests/helpers/safety.bash
source "$TEST_ROOT/suite/tests/helpers/safety.bash"
require_isolation || exit 90
# SCRIPT is supplied by the isolated test setup.
# shellcheck source=refresh_system.sh disable=SC2153
source "$SCRIPT"
initialize_action_registry
"$@"
