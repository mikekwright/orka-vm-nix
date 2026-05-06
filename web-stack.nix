{
  lib,
  pkgs,
  hostname,
  username,
  localConfig ? { },
  ...
}:

let
  homeDirectory = "/Users/${username}";
  normalizedHostname = lib.toLower (lib.replaceStrings [ " " "_" ] [ "-" "-" ] hostname);
  serviceHostName =
    if localConfig ? serviceHostName && localConfig.serviceHostName != "" then
      localConfig.serviceHostName
    else
      "${normalizedHostname}.local";

  portalPublicPort = 8080;
  opencodeUpstreamPort = 9081;
  opencodePublicPort = 8081;
  openVSCodeServerPort = 9082;
  openVSCodeServerPublicPort = 8082;
  codexWebUiPort = 9083;
  codexWebUiPublicPort = 8083;

  portalPublicUrl = "http://${serviceHostName}:${toString portalPublicPort}";
  opencodePublicUrl = "http://${serviceHostName}:${toString opencodePublicPort}";
  openVSCodeServerPublicUrl = "http://${serviceHostName}:${toString openVSCodeServerPublicPort}";
  codexWebUiPublicUrl = "http://${serviceHostName}:${toString codexWebUiPublicPort}";

  openVSCodeServerPackage = pkgs.openvscode-server;
  caddyPwdPackage = pkgs.callPackage ./pkgs/caddy-pwd { inherit caddyAuthFile; };
  codexWebUiPackage = pkgs.callPackage ./pkgs/codex-web-ui { };

  openVSCodeServerRootDirectory = "${homeDirectory}/.local/share/openvscode-server";
  openVSCodeServerUserDataDirectory = "${openVSCodeServerRootDirectory}/user-data";
  openVSCodeServerExtensionsDirectory = "${openVSCodeServerRootDirectory}/extensions";

  caddyAuthFile = "${homeDirectory}/.caddy-basicauth";

  portalSite = pkgs.writeTextDir "index.html" ''
    <!doctype html>
    <html lang="en">
      <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>orka-vm services</title>
        <style>
          body {
            margin: 0;
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
            background: #111827;
            color: #f9fafb;
          }
          main {
            max-width: 760px;
            margin: 48px auto;
            padding: 0 24px;
          }
          h1 {
            margin-bottom: 12px;
          }
          p {
            color: #d1d5db;
          }
          ul {
            list-style: none;
            padding: 0;
            display: grid;
            gap: 12px;
          }
          a {
            display: block;
            padding: 16px 18px;
            border-radius: 12px;
            background: #1f2937;
            color: #93c5fd;
            text-decoration: none;
          }
          a:hover {
            background: #374151;
          }
          code {
            color: #fde68a;
          }
        </style>
      </head>
      <body>
        <main>
          <h1>orka-vm services</h1>
          <p>All services are fronted by one Caddy instance with shared HTTP basic auth.</p>
          <ul>
            <li><a href="${opencodePublicUrl}">OpenCode <code>${opencodePublicUrl}</code></a></li>
            <li><a href="${openVSCodeServerPublicUrl}">openvscode-server <code>${openVSCodeServerPublicUrl}</code></a></li>
            <li><a href="${codexWebUiPublicUrl}">codex-web-ui <code>${codexWebUiPublicUrl}</code></a></li>
          </ul>
        </main>
      </body>
    </html>
  '';

  openVSCodeServerStart = pkgs.writeShellScript "openvscode-server-start" ''
    set -euo pipefail

    umask 077
    mkdir -p "${openVSCodeServerRootDirectory}" "${openVSCodeServerUserDataDirectory}" "${openVSCodeServerExtensionsDirectory}"

    exec ${openVSCodeServerPackage}/bin/openvscode-server \
      --host 127.0.0.1 \
      --port ${toString openVSCodeServerPort} \
      --without-connection-token \
      --user-data-dir "${openVSCodeServerUserDataDirectory}" \
      --extensions-dir "${openVSCodeServerExtensionsDirectory}" \
      "${homeDirectory}"
  '';

  codexWebUiStart = pkgs.writeShellScript "codex-web-ui-start" ''
    set -euo pipefail

    export AUTO_INSTALL_TOOLS=0
    export PATH="${
      lib.makeBinPath [
        pkgs.bash
        pkgs.coreutils
        pkgs.curl
        pkgs.findutils
        pkgs.gnugrep
        pkgs.gnutar
        pkgs.gzip
        pkgs.nodejs
        pkgs.ripgrep
        pkgs.unzip
      ]
    }:/usr/bin:/bin:/usr/sbin:/sbin"

    exec ${codexWebUiPackage}/bin/codex-web-ui \
      --port ${toString codexWebUiPort} \
      --no-open
  '';

  caddyConfig = pkgs.writeText "orka-vm-caddy.Caddyfile" ''
    {
      admin off
      persist_config off
    }

    (authenticated_app) {
      basic_auth * {
        {$CADDY_BASICAUTH_USER} {$CADDY_BASICAUTH_HASH}
      }

      reverse_proxy {args[0]}
    }

    :${toString portalPublicPort} {
      basic_auth * {
        {$CADDY_BASICAUTH_USER} {$CADDY_BASICAUTH_HASH}
      }

      root * ${portalSite}
      file_server
    }

    :${toString opencodePublicPort} {
      import authenticated_app 127.0.0.1:${toString opencodeUpstreamPort}
    }

    :${toString openVSCodeServerPublicPort} {
      import authenticated_app 127.0.0.1:${toString openVSCodeServerPort}
    }

    :${toString codexWebUiPublicPort} {
      import authenticated_app 127.0.0.1:${toString codexWebUiPort}
    }
  '';

  caddyStart = pkgs.writeShellScript "caddy-start" ''
    set -euo pipefail

    if [[ ! -f "${caddyAuthFile}" ]]; then
      printf 'Missing %s\n' "${caddyAuthFile}" >&2
      printf 'Create it with caddy-pwd or with a single username:hashed-password entry.\n' >&2
      exit 1
    fi

    auth_line="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "${caddyAuthFile}")"

    if [[ "$auth_line" != *:* || "$auth_line" == *:*:* ]]; then
      printf 'Expected %s to contain exactly one username:hashed-password entry\n' "${caddyAuthFile}" >&2
      exit 1
    fi

    auth_user="''${auth_line%%:*}"
    auth_hash="''${auth_line#*:}"

    if [[ -z "''${auth_user}" || -z "''${auth_hash}" || "''${auth_user}" == "''${auth_hash}" || "''${auth_hash}" != '$'* ]]; then
      printf 'Expected %s to contain username:hashed-password\n' "${caddyAuthFile}" >&2
      exit 1
    fi

    export CADDY_BASICAUTH_USER="''${auth_user}"
    export CADDY_BASICAUTH_HASH="''${auth_hash}"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_DATA_HOME="$HOME/.local/share"

    mkdir -p "$XDG_CONFIG_HOME/caddy" "$XDG_DATA_HOME/caddy"

    exec ${pkgs.caddy}/bin/caddy run --config "${caddyConfig}" --adapter caddyfile
  '';
in
{
  home.packages = [
    openVSCodeServerPackage
    caddyPwdPackage
    codexWebUiPackage
    pkgs.caddy
    pkgs.nodejs
    pkgs.ripgrep
    pkgs.unzip
  ];

  home.sessionVariables = {
    ORKA_VM_CADDY_PORTAL_URL = portalPublicUrl;
    ORKA_VM_OPENVSCODE_SERVER_URL = openVSCodeServerPublicUrl;
    ORKA_VM_CODE_SERVER_URL = openVSCodeServerPublicUrl;
    ORKA_VM_CODEX_WEB_UI_URL = codexWebUiPublicUrl;
    ORKA_VM_OPENCODE_URL = opencodePublicUrl;
  };

  launchd.agents.openvscode-server = {
    enable = true;
    config = {
      KeepAlive = true;
      ProgramArguments = [ "${openVSCodeServerStart}" ];
      RunAtLoad = true;
      StandardErrorPath = "${homeDirectory}/Library/Logs/openvscode-server.log";
      StandardOutPath = "${homeDirectory}/Library/Logs/openvscode-server.log";
      WorkingDirectory = homeDirectory;
      EnvironmentVariables = {
        HOME = homeDirectory;
      };
    };
  };

  launchd.agents.codex-web-ui = {
    enable = true;
    config = {
      KeepAlive = true;
      ProgramArguments = [ "${codexWebUiStart}" ];
      RunAtLoad = true;
      StandardErrorPath = "${homeDirectory}/Library/Logs/codex-web-ui.log";
      StandardOutPath = "${homeDirectory}/Library/Logs/codex-web-ui.log";
      WorkingDirectory = homeDirectory;
      EnvironmentVariables = {
        HOME = homeDirectory;
      };
    };
  };

  launchd.agents.caddy = {
    enable = true;
    config = {
      KeepAlive = true;
      ProgramArguments = [ "${caddyStart}" ];
      RunAtLoad = true;
      StandardErrorPath = "${homeDirectory}/Library/Logs/caddy.log";
      StandardOutPath = "${homeDirectory}/Library/Logs/caddy.log";
      WorkingDirectory = homeDirectory;
      EnvironmentVariables = {
        HOME = homeDirectory;
      };
    };
  };

  home.file.".config/caddy/README.md".text = ''
    Create ~/.caddy-basicauth with:

      caddy-pwd

    This writes admin:<bcrypt-hash> with restrictive permissions.

    Manual alternative:
      caddy hash-password --plaintext "your-password"

    Example file contents:
      admin:$2a$14$replace-with-your-bcrypt-hash

    Service URLs:
      ${portalPublicUrl}
      ${opencodePublicUrl}
      ${openVSCodeServerPublicUrl}
      ${codexWebUiPublicUrl}
  '';
}
