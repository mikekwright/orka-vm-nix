{
  config,
  lib,
  pkgs,
  inputs,
  username,
  gitUserName,
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
in
{
  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    stateVersion = "25.11";
    packages =
      with pkgs;
      [
        android-tools
        awscli2
        cheat
        cmake
        docker
        docker-compose
        fastfetch
        gh
        git-crypt
        git-lfs
        just
        k9s
        kind
        kubectl
        lazydocker
        meld
        ngrok
        ninja
        nixd
        nixfmt
        podman
        rar
        silver-searcher
        terraform
        zip
      ]
      ++ [
        opencodeWrapped
        opencodePkgs.opencode
      ];
  };

  programs.home-manager.enable = true;

  home.sessionVariables = {
    OPENCODE_SERVE_URL = opencodeUrl;
  };

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
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

  programs.git = {
    enable = true;
    package = pkgs.gitFull;
    lfs.enable = true;
    ignores = [
      ".DS_Store"
      ".direnv/"
      "result"
    ];
    settings = {
      user.name = gitUserName;
      alias = {
        amend = "commit -a --amend";
        prc = "!gh pr create";
        prm = "!gh pr merge -d";
        prs = "!gh pr status";
        prv = "!gh pr view";
        undo = "reset HEAD~1 --mixed";
      };
      branch.autosetupmerge = true;
      color.ui = "auto";
      core.excludesfile = "~/.gitignore_global";
      diff = {
        mnemonicprefix = true;
        tool = "vimdiff";
      };
      merge.tool = "splice";
      pull.rebase = false;
      push = {
        autoSetupRemote = true;
        default = "simple";
      };
      rerere.enabled = true;
    };
  };

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
  };

  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set CONDA_HOME "$HOME/miniconda3"
      if test -f /opt/homebrew/Caskroom/miniconda/base/bin/conda
        set CONDA_HOME "/opt/homebrew/Caskroom/miniconda/base"
      end

      if test -f $CONDA_HOME/bin/conda
        eval $CONDA_HOME/bin/conda "shell.fish" "hook" $argv | source
      else if test -f $CONDA_HOME/etc/fish/conf.d/conda.fish
        . $CONDA_HOME/etc/fish/conf.d/conda.fish
      else
        set -x PATH "$CONDA_HOME/bin" $PATH
      end

      set PATH $PATH /etc/profiles/per-user/${username}/bin
    '';
  };

  home.file = {
    ".gitignore_global".text = ''
      .DS_Store
      .direnv/
      result
    '';
    ".config/opencode/AGENT.md".text = ''
      Keep changes minimal, preserve existing style, and do not introduce secrets.
      Run evaluation or build commands before declaring system changes complete.
    '';
    ".config/opencode/opencode.json".text = builtins.toJSON opencodeConfig;
    ".config/opencode/tui.json".text = builtins.toJSON opencodeTuiConfig;
  };
}
