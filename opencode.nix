{
  pkgs,
  inputs,
  username,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  homeDirectory = "/Users/${username}";
  opencodeHost = "0.0.0.0";
  opencodePort = 9081;
  opencodeUrl = "http://127.0.0.1:${toString opencodePort}";
  opencodePkgs = import inputs.nixpkgs-opencode {
    inherit system;
    config.allowUnfree = true;
  };
  computerControlPackage = pkgs.callPackage ./pkgs/computer-control-mcp { };
  mcpServers = {
    "computer-control" = {
      package = computerControlPackage;
      config = {
        type = "local";
        command = [ "${computerControlPackage}/bin/computer-control-mcp" ];
        enabled = true;
      };
    };
  };
  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    theme = "tokyonight";
    plugin = [ "opencode-browser" ];
    mcp = builtins.mapAttrs (_: server: server.config) mcpServers;
    permission = {
      bash = {
        "*" = "ask";
        "git diff" = "allow";
        "git status" = "allow";
        "ls" = "allow";
        "nix" = "allow";
        "pwd" = "allow";
      };
      webfetch = "ask";
    };
  };

  opencodeTuiConfig = {
    "$schema" = "https://opencode.ai/tui.json";
    keybinds = {
      agent_list = "ctrl+a a";
      command_list = "ctrl+a p";
      input_newline = "shift+return,ctrl+return,alt+return";
      input_submit = "return";
      leader = "ctrl+a";
      model_list = "ctrl+a m";
      session_export = "ctrl+a x";
      session_list = "ctrl+a l";
      session_new = "ctrl+a n";
      sidebar_toggle = "ctrl+a b";
      status_view = "ctrl+a s";
      theme_list = "ctrl+a v";
    };
  };

  opencodeWrapped = pkgs.writeShellScriptBin "opencode" ''
    export OPENCODE_DISABLE_LSP_DOWNLOAD=true
    exec ${opencodePkgs.opencode}/bin/opencode "$@"
  '';

  opencodeWebStart = pkgs.writeShellScript "opencode-web-start" ''
    set -euo pipefail

    password_file="$HOME/.opencode-password"
    age_identity_file="$HOME/.config/age/keys.txt"

    read_password() {
      local file="$1"
      local first_line=""

      IFS= read -r first_line < "$file" || true

      case "$first_line" in
        "-----BEGIN AGE ENCRYPTED FILE-----"|age-encryption.org/*)
          if [[ ! -f "$age_identity_file" ]]; then
            printf 'Encrypted %s found, but %s is missing.\n' "$password_file" "$age_identity_file" >&2
            exit 1
          fi

          ${pkgs.age}/bin/age --decrypt -i "$age_identity_file" "$file" | ${pkgs.coreutils}/bin/tr -d '\r\n'
          ;;
        *)
          ${pkgs.coreutils}/bin/tr -d '\r\n' < "$file"
          ;;
      esac
    }

    export OPENCODE_DISABLE_LSP_DOWNLOAD=true
    unset OPENCODE_SERVER_USERNAME
    unset OPENCODE_SERVER_PASSWORD

    if [[ -f "$password_file" ]]; then
      password="$(read_password "$password_file")"

      if [[ -n "$password" ]]; then
        export OPENCODE_SERVER_USERNAME=opencode
        export OPENCODE_SERVER_PASSWORD="$password"
      fi
    fi

    exec ${opencodePkgs.opencode}/bin/opencode web --hostname ${opencodeHost} --port ${toString opencodePort}
  '';

  darkFactoryManager = ''
    ---
    description: Primary coordinator. Reads the repo, delegates work, and does not edit files directly.
    mode: primary
    temperature: 0.1
    tools:
      write: false
      edit: false
      bash: false
    permission:
      task:
        "*": deny
        dark-factory-spec-builder: allow
        dark-factory-spec-implementor: allow
        dark-factory-scenario-validator: allow
    ---
    You are the manager of the dark-factory workflow. You coordinate the efforts of the spec-builder, spec-implementor, and scenario-validator agents.

    Your role is to enforce:
    - The dark-factory workflow: dark-factory-manager -> dark-factory-spec-builder -> dark-factory-spec-implementor -> dark-factory-scenario-validator.
    - Keep specs, implementation, and validation artifacts separated
    - Delegate work to the specialist agents, You DO NOT edit files directly or execute commands yourself.
    - Always require file based approval before moving from spec-building to implementation

    Dark-Factory project structure:
      project/
        docs/
        scenarios/
          <function>/
            <scenario-1>.yaml
            <scenario-2>.yaml
        specs/
          <feature>/
            spec.md
            plan.md
            approval.md
        ...

    You enforce correct boundaries between the sub-agents:
    - spec-builder: Reviews and updates spec files created by user in the specs/ directory. These are detailed descriptions of what needs to be implemented, including acceptance criteria. It will generate the plan.md from the spec.
    - spec-implementor: Reviews the spec and plan, and once approval is in the approval.md it will implement the changes to fulfill the requirements of the spec and plan.
    - scenario-validator: Reviews user defined scenarios, recommends missing scenarios, and creates new scenarios when requested.  It will also take the scenarios and run them through the system, but it does not have access to the source code at all, just the specs and scenarios.
  '';

  darkFactorySpecBuilder = ''
    ---
    description: Specialist agent responsible for reviewing specs and building detailed plans based on user input and feedback.
    mode: subagent
    temperature: 0.2
    tools:
      write: true
      edit: true
      bash: false
    permission:
      external_directory:
        "*": allow
        "scenarios/": deny
      edit:
        "*": deny
        "specs/": allow
    ---
    You are the plan builder sub-agent for the dark-factory.  

    Your role is to:
    - Generate spec.md templates if requested by the user.
    - Review the spec.md created by the user and provide feedback or recommendations.
    - Make changes to spec.md only if requested by the user.
    - Review the spec.md and generate the plan.md for a given feature, outlining how to implemented the requested spec.
    - Generate the approval.md file once the plan is complete to allow the user to approve the plan.

    You DO NOT have edit access to any files outside of specs/, and you cannot execute any commands.
    You CAN read docs/ for reference on the project.
    You CAN query the web for details on the libraries, and feature requests outlined in the spec.
    You CAN NOT read or write any scenario files under scenarios/.
  '';

  darkFactorySpecImplementor = ''
    ---
    description: Specialist agent responsible for implementing the plans based on the specs and plans created by the spec-builder.
    mode: subagent
    temperature: 0.4
    tools:
      write: true
      edit: true
      bash: true
    permission:
      external_directory:
        "*": allow
        "scenarios/": deny
      edit:
        "*": allow
        "specs/": allow
        "scenarios/": deny
      bash:
        "nix *": allow
        "nix develop *": allow
    ---
    You are the spec implementor sub-agent for the dark-factory.

    Your role is to:
    - Review the spec.md and plan.md files created by the spec-builder and implement the plan.
    - You will not make any changes if the approval.md file is not present, or the file does not contain the approval, as this indicates
      that the plan has not been approved by the user yet.
    - You will generate tests and code to fill the needs of the plan.md, and you will make commits with detailed messages to explain the changes you made.
    - You will only return results to the manager once all plans are implemented and unit and integration tests created all pass successfully.
    - You will follow good software engineering practices, including writing clean and maintainable code, and creating tests to ensure the quality of your implementation.
    - You will follow software design principles to ensure the implementation is modular, extensible, and maintainable.
    - You will use design patterns where appropriate to ensure the implementation is robust and scalable.
    - You will make the code DRY to avoid duplication and ensure maintainability.

    You CAN read docs/ for reference on the project.
    You CAN query the web for details on the libraries, and feature requests outlined in the spec.
    You CAN make changes to all files (except for the specs/ and scenarios/ directories) to implement the features requested in the spec and plan.
    You CAN NOT read or write any scenario files under scenarios/.
  '';

  darkFactoryScenarioValidator = ''
    ---
    description: Specialist agent responsible for validating the implementation based on user defined scenarios.
    mode: subagent
    temperature: 0.2
    tools:
      write: true
      edit: true
      bash: true
    permission:
      external_directory:
        "*": allow
      edit:
        "*": deny
        "scenarios/": allow
    ---
    You are the scenario validator sub-agent for the dark-factory.

    Your role is to:
    - Review user defined scenarios under scenarios/ and provide feedback or recommendations.
    - Recommend additional scenarios that should be added to ensure proper coverage of the implemented features.
    - Implement new scenarios as needed to ensure proper coverage of the implemented features.
    - Take each scenario and create a deterministic validation plan and solution to verify the correctness of each spec using the scenarios.
    - When generating any code you will follow good software engineering practices, including writing clean and maintainable code, and creating tests to ensure the quality of your implementation.
    - You will take the scenarios and run them through the system to validate the implementation.
    - You have access to the code to understand the inputs and outputs of the system, but not the internals.  You will never provide a code change recommendation for failed scenarios, just overview of scenarios that are failing.

    You CAN read docs/ for reference on the project.
    You CAN query the web for details on the libraries, and feature requests outlined in the spec.
    You CAN NOT read or write any spec files under specs/.
  '';
in
{
  home.packages = [
    opencodeWrapped
    pkgs.age
  ]
  ++ builtins.attrValues (builtins.mapAttrs (_: server: server.package) mcpServers);

  home.sessionVariables = {
    OPENCODE_SERVE_URL = opencodeUrl;
  };

  launchd.agents.opencode = {
    enable = true;
    config = {
      KeepAlive = true;
      ProgramArguments = [
        "${opencodeWebStart}"
      ];
      RunAtLoad = true;
      StandardErrorPath = "${homeDirectory}/Library/Logs/opencode.log";
      StandardOutPath = "${homeDirectory}/Library/Logs/opencode.log";
      WorkingDirectory = homeDirectory;
      EnvironmentVariables = {
        HOME = homeDirectory;
        OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
      };
    };
  };

  home.file = {
    ".config/opencode" = {
      "AGENT.md" = ''
        Keep changes minimal, preserve existing style, and do not introduce secrets.
        Run evaluation or build commands before declaring system changes complete.
      '';

      "opencode.json" = builtins.toJSON opencodeConfig;
      "tui.json" = builtins.toJSON opencodeTuiConfig;

      agents = {
        "dark-factory-manager.md".text = darkFactoryManager;
        "dark-factory-spec-builder.md".text = darkFactorySpecBuilder;
        "dark-factory-spec-implementor.md".text = darkFactorySpecImplementor;
        "dark-factory-scenario-validator.md".text = darkFactoryScenarioValidator;
      };
    };
  };
}
