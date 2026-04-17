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
- Local OpenCode MCP server packaging, starting with `computer-control`
- Local machine identity loaded from an ignored `local.nix` file
- OpenCode launch agent that starts automatically at user login

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
- OpenCode runs as a per-user background service on login, listening on `0.0.0.0:9081`.
- Local clients in the VM can still use `http://127.0.0.1:9081`.
- Logs are written to `~/Library/Logs/opencode.log`.

## OpenCode Password

- If `~/.opencode-password` exists, the launch agent starts OpenCode with HTTP basic auth enabled.
- If `~/.opencode-password` does not exist, OpenCode starts without a password.
- The username defaults to `opencode`, matching the current OpenCode docs for `OPENCODE_SERVER_USERNAME`.
- `age` is installed as part of this setup and can be used to keep `~/.opencode-password` encrypted at rest.

### Plaintext password file

```bash
printf '%s\n' 'your-password-here' > ~/.opencode-password
chmod 600 ~/.opencode-password
```

### `age`-encrypted password file

Store an age identity at `~/.config/age/keys.txt`, then encrypt the password file in place:

```bash
mkdir -p ~/.config/age
chmod 700 ~/.config/age
age-keygen -o ~/.config/age/keys.txt
chmod 600 ~/.config/age/keys.txt
printf '%s\n' 'your-password-here' | age -r "$(age-keygen -y ~/.config/age/keys.txt)" -o ~/.opencode-password
chmod 600 ~/.opencode-password
```

The startup script detects plaintext automatically. If `~/.opencode-password` contains an age header, it decrypts it with `~/.config/age/keys.txt` before starting OpenCode.

## Security

- The OpenCode service is intentionally bound to `0.0.0.0:9081` for this Orka VM setup.
- This is only appropriate if the VM network is restricted so that only the host machine can reach the guest.
- If the VM is ever moved to a normal bridged, shared, or otherwise reachable network, change the OpenCode bind address in `home.nix` from `0.0.0.0` back to `127.0.0.1` before using it.
- OpenCode now starts through `opencode web`, and if `~/.opencode-password` exists the service enables HTTP basic auth using that password.
- `computer-control` is enabled as a local MCP server and installed through Nix as part of the same Home Manager configuration.
