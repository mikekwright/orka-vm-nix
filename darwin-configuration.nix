{
  pkgs,
  hostname,
  username,
  ...
}:

{
  networking.hostName = hostname;

  system = {
    primaryUser = username;
    stateVersion = 4;
    defaults = {
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false;
        ApplePressAndHoldEnabled = false;
        InitialKeyRepeat = 15;
        KeyRepeat = 2;
      };
      WindowManager.EnableStandardClickToShowDesktop = false;
      dock = {
        autohide = true;
        autohide-delay = 0.0;
        autohide-time-modifier = 0.0;
        largesize = 96;
        magnification = true;
        tilesize = 24;
      };
    };
  };

  documentation.enable = false;

  nix = {
    enable = true;
    settings = {
      auto-optimise-store = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    gc = {
      automatic = true;
      interval = {
        Weekday = 0;
        Hour = 2;
        Minute = 0;
      };
      options = "--delete-older-than 30d";
    };
  };

  nixpkgs.config.allowUnfree = true;

  ids.gids.nixbld = 350;

  users.users.${username}.home = "/Users/${username}";

  programs.zsh.enable = true;
  programs.fish.enable = true;

  security.pam.services.sudo_local.touchIdAuth = true;

  fonts.packages = with pkgs; [
    nerd-fonts.droid-sans-mono
    nerd-fonts.fira-code
    nerd-fonts.jetbrains-mono
  ];

  environment.systemPackages = with pkgs; [
    any-nix-shell
    curl
    git
    jq
    lsd
    silver-searcher
    vim
    wget
  ];

  homebrew = {
    enable = true;
    onActivation.cleanup = "zap";
    casks = [
      "docker-desktop"
    ];
  };
}
