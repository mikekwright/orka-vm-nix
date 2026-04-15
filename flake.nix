{
  description = "Standalone nix-darwin flake for admins-Virtual-Machine";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };

    homebrew-cask = {
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    nixpkgs-opencode.url = "github:nixos/nixpkgs/66134a4537c8405f1cf22c8e5656b3fe4ece65ca";
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
      system = "aarch64-darwin";
      hostname = "admins-Virtual-Machine";
      localConfigPath = ./local.nix;
      localConfig =
        if builtins.pathExists localConfigPath then
          import localConfigPath
        else
          throw "Copy local.nix.template to local.nix and set username and gitUserName.";
      username = localConfig.username;
      gitUserName = localConfig.gitUserName;
    in
    {
      darwinConfigurations.${hostname} = darwin.lib.darwinSystem {
        inherit system;
        specialArgs = {
          inherit
            inputs
            hostname
            username
            gitUserName
            ;
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
                    hostname
                    username
                    gitUserName
                    ;
                };
                users.${username} = import ./home.nix;
              };
            }
          )
        ];
      };

      formatter.${system} = nixpkgs.legacyPackages.${system}.nixfmt;

      devShells.${system}.default =
        let
          pkgs = import nixpkgs {
            inherit system;
            config.allowUnfree = true;
          };
        in
        pkgs.mkShell {
          packages = with pkgs; [
            darwin-rebuild
            home-manager
            nil
            nixfmt
          ];
        };
    };
}
