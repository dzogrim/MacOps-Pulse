# MacOps Pulse

[![CI](https://github.com/dzogrim/MacOps-Pulse/actions/workflows/tests.yml/badge.svg)](https://github.com/dzogrim/MacOps-Pulse/actions/workflows/tests.yml)

macOS Maintenance & Operations Toolkit powered by `refresh_system.sh`.

MacOps Pulse is a modern and modular Bash toolkit for maintaining,
updating, synchronizing, and auditing a macOS workstation from a
single interactive CLI.

It brings routine system operations together while keeping each task
explicit and independently executable.

## What it does

- **macOS** and **Mac App Store** updates
- **Homebrew**, **MacPorts** and **Nix** maintenance
- **Python** environment management
- Dotfiles and configuration synchronization
- Configuration backups and comparisons
- Application update checks
- Architecture and compatibility checks
- Spotlight and Desktop maintenance
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

## Installation

### Supported platforms

MacOps Pulse is designed for macOS and supports both major Mac architectures:

- Apple Silicon (`arm64`)
- Intel (`x86_64`)

The toolkit has evolved on Intel Macs since 2015 and also supports Apple Silicon.
Architecture-specific checks are performed at runtime where required.

### Requirements

MacOps Pulse requires:

- macOS
- Bash 5 or later
- `fzf` or `gum` for the interactive interface
- Additional tools only for the actions that use them

> [!IMPORTANT]
> The `/bin/bash` bundled with macOS is Bash 3.2 and is **not supported**.
> Install a modern Bash before running MacOps Pulse.

Using Homebrew:

```bash
brew install bash
```

Verify that the Bash selected from your `PATH` is version 5 or later:

```bash
command -v bash
bash --version
```

A Homebrew Bash installation is typically located at:

```text
Apple Silicon: /opt/homebrew/bin/bash
Intel:         /usr/local/bin/bash
```

Ensure the corresponding Homebrew `bin` directory appears before `/bin`
in your `PATH`.

### Install MacOps Pulse

```bash
git clone https://github.com/dzogrim/MacOps-Pulse.git
cd MacOps-Pulse
chmod +x refresh_system.sh
```

Verify the installation and inspect dependencies:

```bash
./refresh_system.sh --help
./refresh_system.sh --check-deps-scpt
./refresh_system.sh --list
```

Install missing optional dependencies when needed:

```bash
./refresh_system.sh --install-deps-scpt
```

### Interactive interface

Install at least one supported selector if it is not already available:

```bash
brew install fzf
```

or:

```bash
brew install gum
```

### Expected local layout

The development repository can be cloned anywhere, for example under a personal
workspace directory.

For operational use, maintenance scripts are expected to live outside the user
home directory, typically under `/opt/Admin/Scripts`.

A typical layout is:

```text
/
├── opt/
│   └── Admin/
│       └── Scripts/
│           ├── refresh_system.sh
│           ├── check_env_shell.sh
│           ├── brew-update.sh
│           ├── ports-update.sh
│           ├── git_refresh.sh
│           ├── <environment/config file>
│           └── <other maintenance scripts>
│
└── Users/
    └── <user>/
        ├── .bashrc
        ├── .bashrc.d/
        ├── .config/
        └── <other user home files>
```

The repository copy is used for development and version control, while the
operational copy of refresh_system.sh and related helper scripts typically
lives under `/opt/Admin/Scripts/` (must be in your env. PATH).

The exact scripts directory and environment/configuration file location are
installation-specific. Keep machine-specific paths, user-specific paths and
creds outside the public repository, and expose them through the expected
local environment or configuration mechanism.

Before using actions that depend on external storage, package managers or
third-party tools, make sure their local paths and dependencies are configured.
Optional dependencies are required only by the actions that use them.

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
