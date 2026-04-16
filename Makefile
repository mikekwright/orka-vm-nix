HOSTNAME := admins-Virtual-Machine
FLAKE := .#$(HOSTNAME)
NIX := nix --extra-experimental-features nix-command --extra-experimental-features flakes

.PHONY: install-nix build switch dry-run check fmt

build:
	$(NIX) build .#darwinConfigurations.$(HOSTNAME).config.system.build.toplevel

install-nix:
	sh <(curl --proto '=https' --tlsv1.2 -L https://nixos.org/nix/install)

switch:
	sudo $(NIX) run nix-darwin -- switch --flake $(FLAKE)

dry-run:
	$(NIX) build .#darwinConfigurations.$(HOSTNAME).config.system.build.toplevel --dry-run

check:
	$(NIX) flake check

fmt:
	$(NIX) fmt
