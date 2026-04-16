{
  pkgs,
  inputs,
  username,
  ...
}:

let
  system = pkgs.stdenv.hostPlatform.system;
  opencodeHost = "0.0.0.0";
  opencodePort = 9081;
  opencodeUrl = "http://127.0.0.1:${toString opencodePort}";
  opencodePkgs = import inputs.nixpkgs-opencode {
    inherit system;
    config.allowUnfree = true;
  };
  opencodeConfig = {
    "$schema" = "https://opencode.ai/config.json";
    theme = "tokyonight";
    plugin = [ "opencode-browser" ];
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
        spec-builder: allow
        spec-implementor: allow
        scenario-validator: allow
    ---
    You are the manager of the dark-factory workflow. You coordinate the efforts of the spec-builder, spec-implementor, and scenario-validator agents.

    Your role is to enforce:
    - The dark-factory workflow: manager -> spec-builder -> spec-implementor -> scenario-validator.
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
in
{
  home.packages = [ opencodeWrapped ];

  home.sessionVariables = {
    OPENCODE_SERVE_URL = opencodeUrl;
  };

  launchd.agents.opencode = {
    enable = true;
    config = {
      KeepAlive = true;
      ProgramArguments = [
        "${opencodePkgs.opencode}/bin/opencode"
        "serve"
        "--hostname"
        opencodeHost
        "--port"
        (toString opencodePort)
      ];
      RunAtLoad = true;
      StandardErrorPath = "/Users/${username}/Library/Logs/opencode.log";
      StandardOutPath = "/Users/${username}/Library/Logs/opencode.log";
      WorkingDirectory = "/Users/${username}";
      EnvironmentVariables = {
        HOME = "/Users/${username}";
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
      };
    };
  };
}
