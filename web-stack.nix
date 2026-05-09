{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.orkaVm.web;
  homeDirectory = config.home.homeDirectory;
in
{
  options.services.orkaVm.web = {
    enable = lib.mkEnableOption "Caddy, openvscode-server, and codex-web-ui launchd services";

    serviceHostName = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Host name or IP used when generating public service URLs.";
    };

    portalPublicPort = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Public Caddy landing-page port.";
    };

    opencodeUpstreamPort = lib.mkOption {
      type = lib.types.port;
      default = 9081;
      description = "Loopback OpenCode upstream port that Caddy proxies to.";
    };

    opencodePublicPort = lib.mkOption {
      type = lib.types.port;
      default = 8081;
      description = "Public Caddy port for OpenCode.";
    };

    openVSCodeServerPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.openvscode-server;
      description = "The openvscode-server package to run.";
    };

    openVSCodeServerPort = lib.mkOption {
      type = lib.types.port;
      default = 9082;
      description = "Loopback openvscode-server upstream port.";
    };

    openVSCodeServerPublicPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Public Caddy port for openvscode-server.";
    };

    codexWebUiPackage = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./pkgs/codex-web-ui { };
      description = "The codex-web-ui package to run.";
    };

    codexWebUiPort = lib.mkOption {
      type = lib.types.port;
      default = 9083;
      description = "Loopback codex-web-ui upstream port.";
    };

    codexWebUiPublicPort = lib.mkOption {
      type = lib.types.port;
      default = 8083;
      description = "Public Caddy port for codex-web-ui.";
    };

    caddyAuthFile = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.caddy-basicauth";
      description = "Path to the username:bcrypt-hash file used by Caddy basic auth.";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      portalPublicUrl = "http://${cfg.serviceHostName}:${toString cfg.portalPublicPort}";
      opencodePublicUrl = "http://${cfg.serviceHostName}:${toString cfg.opencodePublicPort}";
      openVSCodeServerPublicUrl = "http://${cfg.serviceHostName}:${toString cfg.openVSCodeServerPublicPort}";
      codexWebUiPublicUrl = "http://${cfg.serviceHostName}:${toString cfg.codexWebUiPublicPort}";

      caddyPwdPackage = pkgs.callPackage ./pkgs/caddy-pwd {
        caddyAuthFile = cfg.caddyAuthFile;
      };

      openVSCodeServerRootDirectory = "${homeDirectory}/.local/share/openvscode-server";
      openVSCodeServerUserDataDirectory = "${openVSCodeServerRootDirectory}/user-data";
      openVSCodeServerExtensionsDirectory = "${openVSCodeServerRootDirectory}/extensions";

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

        exec ${cfg.openVSCodeServerPackage}/bin/openvscode-server \
          --host 127.0.0.1 \
          --port ${toString cfg.openVSCodeServerPort} \
          --without-connection-token \
          --user-data-dir "${openVSCodeServerUserDataDirectory}" \
          --extensions-dir "${openVSCodeServerExtensionsDirectory}" \
          "${homeDirectory}"
      '';

      codexWebUiStart = pkgs.writeShellScript "codex-web-ui-start" ''
        set -euo pipefail

        exec ${cfg.codexWebUiPackage}/bin/codexui --no-password --no-login --no-open --no-tunnel --port ${toString cfg.codexWebUiPort}
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

        :${toString cfg.portalPublicPort} {
          basic_auth * {
            {$CADDY_BASICAUTH_USER} {$CADDY_BASICAUTH_HASH}
          }

          root * ${portalSite}
          file_server
        }

        :${toString cfg.opencodePublicPort} {
          import authenticated_app 127.0.0.1:${toString cfg.opencodeUpstreamPort}
        }

        :${toString cfg.openVSCodeServerPublicPort} {
          import authenticated_app 127.0.0.1:${toString cfg.openVSCodeServerPort}
        }

        :${toString cfg.codexWebUiPublicPort} {
          import authenticated_app 127.0.0.1:${toString cfg.codexWebUiPort}
        }
      '';

      caddyStart = pkgs.writeShellScript "caddy-start" ''
        set -euo pipefail

        if [[ ! -f "${cfg.caddyAuthFile}" ]]; then
          printf 'Missing %s\n' "${cfg.caddyAuthFile}" >&2
          printf 'Create it with caddy-pwd or with a single username:hashed-password entry.\n' >&2
          exit 1
        fi

        auth_line="$(${pkgs.coreutils}/bin/tr -d '\r\n' < "${cfg.caddyAuthFile}")"

        if [[ "$auth_line" != *:* || "$auth_line" == *:*:* ]]; then
          printf 'Expected %s to contain exactly one username:hashed-password entry\n' "${cfg.caddyAuthFile}" >&2
          exit 1
        fi

        auth_user="''${auth_line%%:*}"
        auth_hash="''${auth_line#*:}"

        if [[ -z "''${auth_user}" || -z "''${auth_hash}" || "''${auth_user}" == "''${auth_hash}" || "''${auth_hash}" != '$'* ]]; then
          printf 'Expected %s to contain username:hashed-password\n' "${cfg.caddyAuthFile}" >&2
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
      assertions = [
        {
          assertion = homeDirectory != null && homeDirectory != "";
          message = "services.orkaVm.web requires home.homeDirectory to be set.";
        }
      ];

      home.packages = [
        cfg.openVSCodeServerPackage
        caddyPwdPackage
        cfg.codexWebUiPackage
        pkgs.caddy
        pkgs.nodejs
        pkgs.ripgrep
        pkgs.unzip
        pkgs.codex
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
        Create ${cfg.caddyAuthFile} with:

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
  );
}
