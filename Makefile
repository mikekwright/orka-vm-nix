HOSTNAME := admins-Virtual-Machine
FLAKE := .#$(HOSTNAME)

.PHONY: build switch dry-run check fmt

build:
	nix build .#darwinConfigurations.$(HOSTNAME).config.system.build.toplevel

switch:
	darwin-rebuild switch --flake $(FLAKE)

dry-run:
	nix build .#darwinConfigurations.$(HOSTNAME).config.system.build.toplevel --dry-run

check:
	nix flake check

fmt:
	nix fmt
