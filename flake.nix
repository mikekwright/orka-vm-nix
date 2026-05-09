{
  description = "nix-darwin flake and reusable Home Manager modules for orka-vm web tooling";

  inputs = {
    # Pinned versions for nixpkgs-unstable 2026-04-16
    nixpkgs.url = "github:nixos/nixpkgs/566acc07c54dc807f91625bb286cb9b321b5f42a";

    darwin = {
      # Pinned version for nix-darwin 2026-04-16
      url = "github:lnl7/nix-darwin/06648f4902343228ce2de79f291dd5a58ee12146";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      # Pinned version for home-manager 2026-04-16
      url = "github:nix-community/home-manager/3c7524c68348ef79ce48308e0978611a050089b2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Pinned version for nix-homebrew 2026-04-16
    nix-homebrew.url = "github:zhaofengli/nix-homebrew/a7760a3a83f7609f742861afb5732210fdc437ed";

    homebrew-core = {
      # Pinned version for homebrew-core 2026-04-16
      url = "github:homebrew/homebrew-core/71192e178db3ac7bd970eb9a4b4b2dc0873ebcf6";
      flake = false;
    };

    homebrew-cask = {
      # Pinned version for homebrew-cask 2026-04-16
      url = "github:homebrew/homebrew-cask/3738e26baf19037cba0be13fb0445bd9fdcff2d2";
      flake = false;
    };

    # Pinner version for opencode version 1.4.6 (2026-04-15)
    nixpkgs-opencode.url = "github:nixos/nixpkgs/44630770ce2af9e12f8e1cfeb8f235a8cdea7452";
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      darwin,
      home-manager,
      nix-homebrew,
      ...
    }:
    let
      supportedSystems = [
        "aarch64-darwin"
        "x86_64-darwin"
      ];

      forEachSystem = nixpkgs.lib.genAttrs supportedSystems;

      mkPkgs = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };

      mkOpencodePkgs = system: import inputs.nixpkgs-opencode {
        inherit system;
        config.allowUnfree = true;
      };

      mkPackages =
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          caddy-pwd = pkgs.callPackage ./pkgs/caddy-pwd { };
          codex-web-ui = pkgs.callPackage ./pkgs/codex-web-ui { };
          computer-control-mcp = pkgs.callPackage ./pkgs/computer-control-mcp { };
          opencode = (mkOpencodePkgs system).opencode;
        };

      homeManagerOpencodeModule =
        { pkgs, ... }@args:
        import ./opencode.nix (
          args
          // {
            opencodePackage = self.packages.${pkgs.stdenv.hostPlatform.system}.opencode;
          }
        );

      homeManagerWebStackModule = import ./web-stack.nix;

      homeManagerDefaultModule =
        { config, lib, ... }:
        {
          imports = [
            homeManagerOpencodeModule
            homeManagerWebStackModule
          ];

          services.orkaVm.web.opencodeUpstreamPort = lib.mkDefault config.services.orkaVm.opencode.port;
        };

      defaultSystem = "aarch64-darwin";
      localConfigPath = ./local.nix;
      hasLocalConfig = builtins.pathExists localConfigPath;
    in
    {
      homeManagerModules = {
        default = homeManagerDefaultModule;
        opencode = homeManagerOpencodeModule;
        web-stack = homeManagerWebStackModule;
      };

      darwinConfigurations =
        if hasLocalConfig then
        let
          system = defaultSystem;
          localConfig = import localConfigPath;

          username = localConfig.username;
          gitUserName = localConfig.gitUserName;
          hostname = localConfig.hostname;
        in
        {
          ${hostname} = darwin.lib.darwinSystem {
            inherit system;
            specialArgs = {
              inherit
                inputs
                localConfig
                hostname
                username
                gitUserName
                ;
              opencodePackage = self.packages.${system}.opencode;
            };
            modules = [
              nix-homebrew.darwinModules.nix-homebrew
              home-manager.darwinModules.home-manager
              ./darwin-configuration.nix
              (
                { config, ... }:
                {
                  nix-homebrew = {
                    enable = true;
                    enableRosetta = true;
                    user = username;
                    taps = {
                      "homebrew/homebrew-core" = inputs.homebrew-core;
                      "homebrew/homebrew-cask" = inputs.homebrew-cask;
                    };
                    mutableTaps = false;
                  };

                  homebrew.taps = builtins.attrNames config.nix-homebrew.taps;

                  home-manager = {
                    useGlobalPkgs = true;
                    useUserPackages = true;
                    extraSpecialArgs = {
                      inherit
                        inputs
                        localConfig
                        hostname
                        username
                        gitUserName
                        ;
                      opencodePackage = self.packages.${system}.opencode;
                    };
                    users.${username} = import ./home.nix;
                  };
                }
              )
            ];
          };
        }
        else
          { };

      formatter = forEachSystem (system: (mkPkgs system).nixfmt);

      packages = forEachSystem mkPackages;

      apps = forEachSystem (
        system:
        let
          packages = mkPackages system;
        in
        {
          caddy-pwd = {
            type = "app";
            program = "${packages.caddy-pwd}/bin/caddy-pwd";
            meta.description = "Create or replace the Caddy basic-auth file";
          };
        }
      );

      devShells = forEachSystem (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              darwin.packages.${system}.default
              pkgs.home-manager
              pkgs.nil
              pkgs.nixfmt
            ];
          };
        }
      );
    };
}
