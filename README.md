# orka-vm-nix

A VM for OpenCode for you mac system (create a droid)

## Overview

Standalone public-safe flake for the `admins-Virtual-Machine` macOS VM.

This repo is intentionally scoped to a single machine instead of a shared multi-host dotfiles setup.

### What is included

- `nix-darwin` system configuration for `admins-Virtual-Machine`
- `home-manager` configuration for `mikewright`
- `nix-homebrew` integration with pinned Homebrew taps
- Safe OpenCode installation and local configuration
- Local machine identity loaded from an ignored `local.nix` file

### What is intentionally not included

- API tokens, MCP credentials, or private service endpoints
- multi-machine abstractions from the original dotfiles repo

## Install

The first thing you need is to install nix on darwin (if needed).

```bash
make install-nix
```

## Build

First copy the template and fill in your local values:

```bash
cp local.nix.template local.nix
```


You will then need to add it to the git repo (don't commit) just so nix will correctly include the file in the build process

```bash
git add -f local.nix
```

Then build:

```bash
nix --enable-experimental-features nix-command --enable-experimental-features flakes build .#darwinConfigurations.admins-Virtual-Machine.config.system.build.toplevel
```

## Switch

```bash
nix --enable-experimental-features nix-command --enable-experimental-features flakes run nix-darwin -- switch --flake .#admins-Virtual-Machine
```

## Notes

- OpenCode is configured with safe defaults only. Add any private providers or MCP server credentials separately outside this repo.
- Personal values such as macOS username and git user name belong in `local.nix`, which is gitignored.
