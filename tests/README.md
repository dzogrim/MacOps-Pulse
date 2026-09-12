# Isolated regression tests

Run from the repository root:

```sh
./tests/bootstrap.bash  # one-time, pinned project-local Bats-core v1.11.0
./tests/run
./tests/run --filter 'timeout|deadline' --print-output-on-failure
```

Requirements: macOS with working `sandbox-exec`, Bash 5.x, jq, Python 3, and Apple
command-line tools (`otool`, `install_name_tool`, `codesign`). Bootstrap requires Git
and network access; test execution requires neither. No global packages are installed.
Bats is pinned to commit `5da66876b8b619235aee1eb3e54954eaca88059b` and ignored under
`.test-tools/`. `BATS_CORE_ROOT` can select an already prepared Bats-core checkout.

**Use `tests/run`, not direct `bats tests`.** The launcher is a preparation boundary:
it resolves and copies dependencies, clears its inherited environment, and launches
Bats only after the macOS sandbox preflight succeeds. There is no unsandboxed fallback.
When invoked from another restricted sandbox, the launcher may need permission to
start its own sandbox; refusal stops execution before the test subject is run.

## Safety model

* A fresh physical `/private/tmp/refresh-tests-*` directory contains the staged
  script, Bats, Bash, jq, their non-system libraries, all fixtures and all output.
  Runtime load paths are rewritten and the copied binaries are signed locally.
  Tests do not load runtime libraries from Homebrew or MacPorts installations.
* Child environments are allowlisted, with synthetic HOME, TMPDIR, working directory,
  user names and PATH. Each Bats case then gets a separate home, mock bin and call log.
  No original home, repository path, shell profile, account configuration or exported
  function is forwarded. Bats' internal TEST_ROOT name is handled explicitly.
* The deny-default Seatbelt profile permits reads only of staged files and selected
  system runtime paths. Writes are confined to TEST_ROOT and output devices.
  Account-service IPC, process-information queries, network access, and execution of
  real maintenance utilities are denied. The profile does not permit workstation
  home, application, package-manager or Nix-profile access.
* PATH mocks record arguments and reject mutations by default. Only individual tests
  grant deterministic mock behavior. `sudo` never delegates. File movement/removal
  wrappers reject external paths, traversal and symlink components before operating.
* Fatal paths run in child Bash processes. The fzf test checks that its exact PID is
  gone; the outer launcher bounds the entire suite at 120 seconds and terminates only
  its own process group on exit. Teardown validates the root's location, inode and
  symlink state before deleting it.

The host-aware launcher only prepares files; it never executes maintenance logic.
System loader/runtime reads are necessarily permitted; this is not a virtual machine.
Do not add real application integration tests to this suite. Changes to the sandbox
policy deserve separate review, especially execution, IPC, network and write rules.

## First-wave risk map (35 tests)

| Area | Regression prevented |
| --- | --- |
| CLI and registry | Invalid input dispatch, extra IDs, broken metadata and handlers |
| Environment | Missing account settings, unsupported install account, wrong platform |
| Execution wrappers | Soft failures becoming fatal, fatal failures continuing, real sudo |
| Dropbox / pip | Invalid JSON/path types, unavailable roots fabricated, wrong account suffix |
| Mackup | Unsupported engines, unavailable storage, missing filesystem configuration |
| Screenshots / Desktop | Incorrect date destinations, unrelated file movement, alias reporting |
| Architectures / optional tools | Universal binaries misclassified, missing tools blocking work |
| Selectors | Timeout accepting action 2, cancellation dispatch, broken structured IDs |
| Helper modes | Full-maintenance dependency coupling and unavailable Dropbox destination |
| Harness | Missing isolation, unsafe fixture paths, source-time execution |

The tests exercise the real functions and CLI. Action 2 executes its real handler
against a harmless comparison-script mock. JSON tests use the staged real jq; the
legacy case has a child PATH without jq (including macOS's bundled `/usr/bin/jq`).
Screenshot fallback uses real macOS stat on a synthetic file with a fixed timestamp.
Account validation currently checks nonempty values, not the OS account database;
unknown-account rejection is tested at the actual installation-path resolver.
The production key is spelled `ADM_SHELL_USER_PROv1`.

Menus are mocked: tests validate exact default-focus arguments, structured selection,
status handling, no dispatch on timeout, and fzf process cleanup. They do not establish
real gum/fzf visual rendering, keyboard handling, or terminal restoration. Gum's mock
returns native timeout status 124; fzf's real Bash deadline interrupts a blocking mock.

## Minimal production changes

1. A source guard defines functions/constants without starting CLI execution. Direct
   execution retains its existing flow. Tests initialize the registry explicitly.
2. TIMEOUT_SEC accepts a caller override, retaining 50 as the unset/empty default.
   Tests shorten fzf's deadline to one second.
3. The Free Claude Code Desktop link uses `$HOME` instead of an embedded username.
   This removes workstation identity from the staged subject and allows synthetic
   home resolution. That updater is not executed by this suite.

Version, registry, dispatcher and maintenance commands otherwise remain unchanged.
No production defect was demonstrated by this iteration.

## Validation and next iteration

Run static checks from the repository root:

```sh
bash -n refresh_system.sh
shellcheck refresh_system.sh tests/helpers/*.bash tests/bootstrap.bash tests/run tests/*.bats
```

Useful next cases: screenshot move failures; pip/pipx partial failures; mock Gist
clone/install failures and cleanup; real selector PTY behavior in an equally isolated
runtime. Keep account-service and workstation access blocked.


## Compatibility wave (45 additional tests; 80 total)

`compat_*.bats` adds behavior checks without production refactoring or sandbox-policy
changes. `helpers/compat.bash` provides disposable heredoc probes, narrow mock setup,
and function execution tracing. Trace assertions observe actual CLI execution and
prove no action handler was entered; they do not inspect production source text.

| Area | Additional contracts |
| --- | --- |
| Platform | Darwin startup independent of mocked macOS versions and reported CPU |
| BSD utilities | Native awk grouping/filtering, find permissions, sort order, stat timestamps, non-overwriting mv |
| Registry | Complete ordered list parity, dispatch identity for all 33 IDs, invalid registration and missing handlers |
| Lifecycle | Metadata isolation, exactly one direct action, invalid CLI never dispatches, inert sourcing |
| Menus | Native 124/130, arbitrary failures, empty/malformed/unregistered output, missing-selector fallback |
| Terminal/locale | Apple Terminal, iTerm, unknown/empty terminal, non-TTY dumb output; C, English/French UTF-8 |
| Paths | Spaces, accents, apostrophes, brackets, emoji, collisions, empty environment values |
| Dependencies | Mandatory command errors, minimal helper startup, missing lipo, optional Nix helper absence |
| Privilege/batches | Exact sudo arguments, fatal propagation, ordered unique attempts, soft continuation and aggregate status |
| Escape resistance | Empty paths, traversal, external symlink chains and multiline traversal strings |

The implementation has **no sw_vers-based version parser, semantic version comparator,
Rosetta detection, mdls call, or date-command parser**. Tests do not invent these
features: they verify platform independence, version-string preservation in MacUpdater
output, and that iTerm's guard does not require metadata tools. CPU classification
uses mocked binary reports (Intel-only, ARM-only, universal), never installed binaries.
This establishes simulated contracts, not execution on multiple OS releases or CPUs.

All three tested locales are available on the validation host. Menus remain mocked;
no real terminal or package manager is exercised. The existing 120-second suite bound,
per-case HOME/TMPDIR, PATH mocks, and deny-default macOS sandbox remain intact.

One **test-harness defect** was found: the path guard used line-oriented `read`, so it
could validate only the first line of a multiline pathname. The guard now rejects CR
and LF before splitting components. The retained regression checks rejection before
rm/mv delegate. The OS sandbox remained the independent boundary throughout.
No production compatibility defect was demonstrated and `refresh_system.sh` was not
modified in this wave.
