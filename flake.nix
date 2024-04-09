# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  description = "The measurement device gateway for SEGuRo";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    nixos-shell = {
      url = "github:Mic92/nixos-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    villas-node = {
      url = "github:VILLASframework/node";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    seguro-platform = {
      url = "github:SEGuRo-Projekt/Platform";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      poetry2nix,
      villas-node,
      ...
    }@inputs:
    let
      inherit (builtins) readDir;
      inherit (nixpkgs.lib) mapAttrs;

      dirEntries =
        path:
        let
          toPath = n: v: path + "/${n}";
        in
        mapAttrs toPath (readDir path);

      forDirEntries = path: f: mapAttrs f (dirEntries path);

      pkgOverlay =
        final: prev: (forDirEntries ./nix/packages (name: path: prev.callPackage path { inherit inputs; }));

      overlays = [
        pkgOverlay
        poetry2nix.overlays.default
      ];
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          inherit overlays;
        };
      in
      {
        # A development shell to be used with `nix develop`
        devShells.default = pkgs.mkShell {
          buildInputs = [
            (pkgs.poetry2nix.mkPoetryEnv {
              projectDir = ./.;
              editablePackageSources = {
                seguro = ./seguro;
              };
              overrides = pkgs.poetry2nix.defaultPoetryOverrides.extend (
                self: super: { cryptography = pkgs.python311Packages.cryptography; }
              );
            })
          ];

          packages = with pkgs; [
            poetry
            reuse
            pre-commit

            nix-render-template
            villas-generate-gateway-config
            start-vm
          ];
        };
      }
    )
    // {
      nixosModules =
        let
          mkNixosModule = name: path: import path;
        in
        forDirEntries ./nix/nixosModules mkNixosModule;

      nixosConfigurations =
        let
          parse =
            hostname:
            { system, modules }:
            {
              inherit system;
              modules = modules ++ [ { nixpkgs.overlays = self.overlays; } ];
              specialArgs = inputs // {
                inherit hostname;
              };
            };
          mkNixosConfiguration = name: path: nixpkgs.lib.nixosSystem (parse name (import path));
        in
        forDirEntries ./nix/nixosConfigurations mkNixosConfiguration;

      secrets = dirEntries ./nix/secrets;

      inherit overlays;
    };
}
