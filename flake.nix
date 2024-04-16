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
      seguro-platform,
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

      packagesOverlay =
        final: prev: (forDirEntries ./nix/packages (name: path: prev.callPackage path { inherit inputs; }));
    in
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          inherit (self) overlays;
        };
      in
      {
        # Define the SD-Card image as our default build derivation
        # This allows us to simply run "nix build" inside our repo to build an image.
        packages.default = self.nixosConfigurations.rpi-1.config.system.build.sdImage;

        devShells.default = pkgs.callPackage ./nix/shell.nix { };
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

      overlays = [
        packagesOverlay
        poetry2nix.overlays.default
        seguro-platform.overlays.default
      ];
    };
}
