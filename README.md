# MacOps Pulse

[![CI](https://github.com/dzogrim/MacOps-Pulse/actions/workflows/tests.yml/badge.svg)](https://github.com/dzogrim/MacOps-Pulse/actions/workflows/tests.yml)

macOS Maintenance & Operations Toolkit powered by `refresh_system.sh`.

MacOps Pulse is a modular Bash toolkit for maintaining, updating,
synchronizing, and auditing a macOS workstation from a single
interactive CLI.

It brings routine system operations together while keeping each task
explicit and independently executable.

## What it does

- macOS and Mac App Store updates
- Homebrew, MacPorts and Nix maintenance
- Python environment management
- Dotfiles and configuration synchronization
- Configuration backups and comparisons
- Application update checks
- Architecture and compatibility checks
- Spotlight and desktop maintenance
- Misc. monitoring checks
- Batch update, backup and comparison workflows

## Usage

Launch the interactive menu:

``` bash
./refresh_system.sh
```

Or select an interface explicitly:

``` bash
./refresh_system.sh --fzf
./refresh_system.sh --gum
```

List available actions:

``` bash
./refresh_system.sh --list
```

Run a specific action directly:

``` bash
./refresh_system.sh --run <ID>
```

Display all options:

``` bash
./refresh_system.sh --help
```

## Requirements

- macOS
- Bash 5+
- `fzf` or `gum` for the interactive interface
- Additional tools are required only by their corresponding actions

## Philosophy

MacOps Pulse favors small, explicit and composable maintenance actions
over opaque system automation.

Potentially unavailable tools are detected at runtime, and operations
can be executed individually or as grouped workflows.

## Tests

MacOps Pulse includes a non-regression test suite built around an isolated
sandbox environment.

Run the full test suite with:

```bash
./tests/run
```

The tests are designed to avoid interacting with the real user environment,
including the actual $HOME, Desktop, Dropbox, package managers, and
privileged system operations.

## License

This project is licensed under the [MIT License](LICENSE).
