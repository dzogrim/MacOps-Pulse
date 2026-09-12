# MacOps Pulse

[![CI](https://github.com/dzogrim/MacOps-Pulse/actions/workflows/tests.yml/badge.svg)](https://github.com/dzogrim/MacOps-Pulse/actions/workflows/tests.yml)

macOS Maintenance & Operations Toolkit powered by `refresh_system.sh`.

MacOps Pulse is a modern, modular Bash toolkit for maintaining, updating,
synchronizing and auditing a macOS workstation from a single interactive CLI.

It brings routine system operations together while keeping each task explicit
and independently executable.

## What it does

- **macOS** and **Mac App Store** updates
- **Homebrew**, **MacPorts** and **Nix** maintenance
- **Python** environment management
- Dotfiles and configuration synchronization
- Configuration backups and comparisons
- Application update checks
- Architecture and compatibility checks
- Spotlight and Desktop maintenance
- Miscellaneous monitoring checks
- Batch update, backup and comparison workflows

## Usage

> [!NOTE]
> Apple Terminal.app is fully supported, but a modern terminal emulator such as
> iTerm2 is recommended for a better interactive experience.

Launch the interactive menu:

```bash
./refresh_system.sh
```

Or select an interface you like explicitly:

```bash
./refresh_system.sh --fzf
./refresh_system.sh --gum
```

List available actions:

```bash
./refresh_system.sh --list
```

Run a specific action directly:

```bash
./refresh_system.sh --run <ID>
```

Display all available command-line arguments:

```bash
./refresh_system.sh --help
```

## Installation

### Supported platforms

MacOps Pulse is designed for **macOS** and supports both **Mac** architectures:

- Apple Silicon (`arm64`)
- Intel (`x86_64`)

The toolkit has been developed and used on Intel Macs since 2015 and also
supports Apple Silicon.

Architecture-specific checks are performed at runtime where required.

### Requirements

The core `refresh_system.sh` script requires:

- macOS
- **Bash 5** or later
- `fzf` or `gum` for the interactive interface
- Optionally `git` for cloning and updating the repository

Additional tools are required only by the actions that use them.

> [!IMPORTANT]
> The `/bin/bash` bundled with macOS is **Bash 3.2** and is **not supported**.
> A modern Bash installation is required.

Compare the system-provided Bash with the Homebrew version:

| Installation | Command | Typical version | Supported |
| --- | --- | --- | --- |
| macOS system | `/bin/bash --version` | Bash 3.2.57 | ❌ No |
| Homebrew | `/opt/homebrew/bin/bash --version` | Bash 5.3+ | ✅ Yes |

### Install Bash

The easiest way to install a current Bash version on macOS is with
[Homebrew](https://brew.sh):

```bash
brew install bash
```

Verify that Bash 5 or later is available:

```bash
command -v bash
bash --version
```

A Homebrew Bash installation is typically located at:

- Apple Silicon (`arm64`): `/opt/homebrew/bin/bash`.
- Intel (`x86_64`): `/usr/local/bin/bash` (legacy).

Ensure the corresponding Homebrew `bin` directory appears **before**
`/bin` in your `PATH`.

### Install MacOps Pulse

Clone this repository.

Or simply download the [`refresh_system.sh`](refresh_system.sh) script.

Ensure the `refresh_system.sh` is executable:

```bash
chmod +x refresh_system.sh
```

Verify the installation and inspect its dependencies:

```bash
./refresh_system.sh --help
./refresh_system.sh --check-deps-scpt
```

Install missing optional dependencies when required:

```bash
./refresh_system.sh --install-deps-scpt
```

Finally, list the available maintenance actions:

```bash
./refresh_system.sh --list
```

### Interactive interface

MacOps Pulse supports both `fzf` and `gum` as interactive selectors.

Install either one:

```bash
brew install fzf
```

or:

```bash
brew install gum
```

Both may be installed at the same time.

## Recommended local layout

MacOps Pulse separates operational scripts from user-specific configuration.

Maintenance scripts are typically stored outside the user's home directory,
under `/opt/Admin/Scripts`.

User-specific configuration remains under the user's home directory.

A typical installation looks like this:

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
│           └── <other maintenance scripts>
│
└── Users/
    └── <user>/
        ├── .bashrc
        ├── .bashrc.d/
        ├── .config/
        │   └── AdminHelpers/
        │       └── env
        └── <other user files>
```

`/opt/Admin/Scripts` is used for executable maintenance scripts, while
`~/.config/AdminHelpers/env` contains workstation- and user-specific settings.

> [!NOTE]
> `/opt` is outside the user's home directory and may initially require
> administrator privileges to create. Once configured with appropriate ownership
> and permissions, normal use of MacOps Pulse should not require modifying files
> as `root`.

If an alternative scripts directory is used, configure the corresponding path
in the environment file and ensure the directory is available in your `PATH`
when required.

Some environments may use `/usr/local/Admin/helpers` instead of
`/opt/Admin/Scripts`.

### Environment file

MacOps Pulse uses a local environment file for settings that vary between Macs
or users:

```text
~/.config/AdminHelpers/env
```

This keeps machine-specific configuration separate from the public repository.

Only variables required by the actions you actually use need to be defined.
Typical values include:

- the local username
- the directory containing administrative helper scripts
- local storage or synchronization paths
- tool-specific configuration used by individual actions

A minimal example is an environment that uses a separate professional
helper location could use:

```bash
ADM_SHELL_USER_PROv1="marie.martin"
ADM_SHELL_USER_PERSO="marie-martin"

ADM_SHELL_SCPT_PROv1="${HOME}/.local/Admin/helpers"
ADM_SHELL_SCPT_PERSO="/opt/Admin/Scripts"
```

> [!IMPORTANT]
> The environment file is local configuration and must **never** be committed to
> the public repository.
>
> Do not store any creds in the repository.

Create the configuration directory if necessary:

```bash
mkdir -p "${HOME}/.config/AdminHelpers"
```

The environment file should be readable only by the current user:

```bash
chmod 600 "${HOME}/.config/AdminHelpers/env"
```

Before using actions that depend on external storage, package managers or
third-party tools, make sure their required paths and dependencies are
configured.

Optional dependencies are required only by the actions that use them.

## Philosophy

MacOps Pulse favors small, explicit and composable maintenance actions over
opaque system automation.

Potentially unavailable tools are detected at runtime, and operations can be
executed individually or as grouped workflows.

## Tests (Development)

MacOps Pulse includes a non-regression test suite built around an isolated
sandbox environment.

Run the full test suite with:

```bash
./tests/run
```

The tests are designed to avoid interacting with the real user environment,
including the actual `$HOME`, Desktop, Dropbox, iCloud, package managers and
privileged system operations.

## License

This project is licensed under the [MIT License](LICENSE).
