{
  pkgs,
  username,
  gitUserName,
  ...
}:

{
  imports = [ ./opencode.nix ];

  home = {
    username = username;
    homeDirectory = "/Users/${username}";
    stateVersion = "25.11";
    packages = with pkgs; [
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
    ];
  };

  programs.home-manager.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
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
  };
}
