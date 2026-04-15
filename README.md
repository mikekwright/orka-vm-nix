# orka-vm-nix

Standalone public-safe flake for the `admins-Virtual-Machine` macOS VM.

This repo is intentionally scoped to a single machine instead of a shared multi-host dotfiles setup.

## What is included

- `nix-darwin` system configuration for `admins-Virtual-Machine`
- `home-manager` configuration for `mikewright`
- `nix-homebrew` integration with pinned Homebrew taps
- Safe OpenCode installation and local configuration
- Local machine identity loaded from an ignored `local.nix` file

## What is intentionally not included

- `sensitive.nix`
- API tokens, MCP credentials, or private service endpoints
- multi-machine abstractions from the original dotfiles repo

## Build

First copy the template and fill in your local values:

```bash
cp local.nix.template local.nix
```

Then build:

```bash
nix build .#darwinConfigurations.admins-Virtual-Machine.system
```

## Switch

```bash
darwin-rebuild switch --flake .#admins-Virtual-Machine
```

## Notes

- OpenCode is configured with safe defaults only. Add any private providers or MCP server credentials separately outside this repo.
- Personal values such as macOS username and git user name belong in `local.nix`, which is gitignored.
