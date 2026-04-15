HOSTNAME := admins-Virtual-Machine
FLAKE := .#$(HOSTNAME)
NIX := nix --enable-experimental-features nix-command --enable-experimental-features flakes

.PHONY: install-nix build switch dry-run check fmt

install-nix:
	sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)

build:
	$(NIX) build .#darwinConfigurations.$(HOSTNAME).config.system.build.toplevel

switch:
	$(NIX) run nix-darwin -- switch --flake $(FLAKE)

dry-run:
	$(NIX) build .#darwinConfigurations.$(HOSTNAME).config.system.build.toplevel --dry-run

check:
	$(NIX) flake check

fmt:
	$(NIX) fmt
