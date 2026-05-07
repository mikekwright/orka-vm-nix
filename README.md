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
- `openvscode-server` installed from the main Nix package set and started automatically on login
- `codex` CLI installed through Nix for terminal use, plus `codex-app` through Homebrew for `codex-web-ui`
- A user-scoped Caddy reverse proxy in front of OpenCode, `openvscode-server`, and `codex-web-ui`
- Shared HTTP basic auth at the Caddy layer for all exposed web apps
- An authenticated landing page on `:8080` with links to the exposed services
- Local OpenCode MCP server packaging, starting with `computer-control`
- Local machine identity loaded from an ignored `local.nix` file
- Launch agents that start OpenCode, `openvscode-server`, `codex-web-ui`, and Caddy automatically at user login

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

Set `serviceHostName` to the hostname or IP you want used in the generated helper URLs.

- Use an IP if you do not want DNS at all.
- Use a hostname if you want nicer URLs.


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
- The `codex` CLI is installed from Nix for direct terminal use and should be available on your shell `PATH` after switching.
- OpenCode now listens on `127.0.0.1:9081` and is intended to be reached through the local Caddy reverse proxy.
- `codex-web-ui` is started locally and still expects `Codex.app` to exist at `/Applications/Codex.app`, which is currently provided by the `codex-app` Homebrew cask; it does not replace that dependency with the Nix CLI.
- The packaged `codex-web-ui` wrapper verifies that the upstream npm bundle still includes `webui-bridge.js` and binds its internal listener to loopback by default so it stays behind Caddy.
- The web access stack uses these public ports on the VM:
  - `8080` - Caddy landing page
  - `8081` - OpenCode
  - `8082` - `openvscode-server`
  - `8083` - `codex-web-ui`
- Logs are written to `~/Library/Logs/{opencode,openvscode-server,codex-web-ui,caddy}.log`.
- The same Caddy HTTP basic auth credentials are used for the landing page and all three proxied app ports.
- Shell sessions export `ORKA_VM_OPENVSCODE_SERVER_URL`, and `ORKA_VM_CODE_SERVER_URL` remains as a compatibility alias.

## Caddy Basic Auth Setup

Create `~/.caddy-basicauth` with a single `username:bcrypt-hash` entry before expecting the proxied web apps to work.

Before switching this configuration, you can create it directly from the flake:

```bash
nix --extra-experimental-features nix-command --extra-experimental-features flakes run .#caddy-pwd
```

After switching, the helper is available on your PATH:

```bash
caddy-pwd
```

`caddy-pwd` prompts for a password, defaults the username to `admin`, and writes `~/.caddy-basicauth` with mode `600`.

For automation, you can pass the password on stdin:

```bash
printf '%s' 'your-password' | caddy-pwd --stdin --force
```

Manual alternative:

```bash
nix shell nixpkgs#caddy -c caddy hash-password --plaintext 'your-password'
```

Example `~/.caddy-basicauth` contents:

```text
admin:$2a$14$replace-with-your-bcrypt-hash
```

Create the file with restrictive permissions:

```bash
printf '%s\n' 'admin:$2a$14$replace-with-your-bcrypt-hash' > ~/.caddy-basicauth
chmod 600 ~/.caddy-basicauth
```

Rules for `~/.caddy-basicauth`:

- exactly one line
- exactly one `:` separator
- format: `username:bcrypt-hash`
- the hash should be the output of `caddy hash-password`

If this file is missing or malformed, the Caddy launch agent will fail to start until it is fixed.

If you want to recreate it cleanly, run `caddy-pwd --force`.

## Service URLs

Once the system is switched and the Caddy auth file exists, use:

- landing page: `http://<serviceHostName>:8080`
- OpenCode: `http://<serviceHostName>:8081`
- openvscode-server: `http://<serviceHostName>:8082`
- codex-web-ui: `http://<serviceHostName>:8083`

If `serviceHostName` is set to an IP, replace `<serviceHostName>` with that IP directly.

## IP Address Support

- Caddy basic auth works fine over a bare IP address, so DNS is no longer required for the authentication layer.
- If you prefer a hostname, `serviceHostName` can still be a local DNS name or `/etc/hosts` entry.

Example `local.nix` value when using an IP directly:

```nix
serviceHostName = "10.0.0.25";
```

Example `local.nix` value when using a hostname:

```nix
serviceHostName = "vm-hostname.local";
```

## OpenVSCode Server Note

- `openvscode-server` itself is proxied correctly, but browser features that require a secure context can still be limited when you use plain HTTP from another machine.
- If you need full webview behavior, plan on adding HTTPS with Caddy later.
- Existing `code-server` settings and extensions remain under `~/.local/share/code-server`; `openvscode-server` uses `~/.local/share/openvscode-server` and does not migrate that state automatically.

## Services Started Automatically

On login, Home Manager starts user services for:

- OpenCode
- openvscode-server
- codex-web-ui
- Caddy

If one of the prerequisites is missing, the affected service can fail and retry through launchd. The two most common causes are:

- missing `~/.caddy-basicauth`
- `Codex.app` not present at `/Applications/Codex.app`

Caddy starts independently and no longer waits for the backend apps to be listening before it binds its public ports.

## Direct OpenCode Password

- When using the Caddy stack, OpenCode's own built-in password is disabled by default so that the proxy remains the only external login layer.
- Only enable direct OpenCode auth if you explicitly set `enableDirectOpencodeAuth = true;` in `local.nix`.
- If direct auth is enabled and `~/.opencode-password` exists, the launch agent starts OpenCode with HTTP basic auth enabled.
- If direct auth is enabled and `~/.opencode-password` does not exist, OpenCode starts without a password.
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

## Troubleshooting

### A service does not start

Check whether the user launch agents are loaded:

```bash
launchctl list | grep -E 'caddy|openvscode-server|codex-web-ui|opencode'
```

Check logs:

```bash
tail -f ~/Library/Logs/caddy.log
tail -f ~/Library/Logs/openvscode-server.log
tail -f ~/Library/Logs/codex-web-ui.log
tail -f ~/Library/Logs/opencode.log
```

### Caddy is not starting

Common causes:

- `~/.caddy-basicauth` is missing
- `~/.caddy-basicauth` is malformed
- one of the public ports is already in use

If Caddy is running but one app is still starting, that route can return an upstream error until the backend is listening.

Verify the auth file format:

```text
username:$2a$14$...
```

### codex-web-ui is not starting

`codex-web-ui` expects:

- `codex` available from the managed Nix environment
- `Codex.app` installed at `/Applications/Codex.app`
- Node available from the managed environment
- the upstream `webui-bridge.js` runtime asset present in the packaged wrapper output

If the app is missing, make sure the `codex-app` cask installed successfully.

### `local.nix` changes are ignored during build

This repo expects `local.nix` to be present in the git index during evaluation.

```bash
git add -f local.nix
```

Do not commit it.

### The browser can reach the page but openvscode-server features are broken

If you are using plain HTTP from another machine, browser secure-context restrictions can affect openvscode-server features such as webviews.

The fix is to add HTTPS later through Caddy.

### A port is already in use

This setup expects:

- `8080` for the landing page
- `8081` for OpenCode
- `8082` for openvscode-server
- `8083` for codex-web-ui
- `9081` for the internal OpenCode listener
- `9082` for the internal openvscode-server listener
- `9083` for the internal codex-web-ui listener

If one of those is already occupied, the related service will fail to start.

## Security

- OpenCode is now loopback-only and is exposed externally through the Caddy reverse proxy.
- Caddy basic auth is the intended external authentication layer for the proxied apps.
- Bare-IP access is supported by the current Caddy auth setup.
- OpenCode still starts through `opencode web`, and direct OpenCode HTTP basic auth is now opt-in through `enableDirectOpencodeAuth = true;` in `local.nix`.
- `computer-control` is enabled as a local MCP server and installed through Nix as part of the same Home Manager configuration.
