# SPDX-FileCopyrightText: 2024 OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  description = "Gateway apps for SEGuRp";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      # see https://github.com/nix-community/poetry2nix/tree/master#api for more functions and examples.
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (poetry2nix.lib.mkPoetry2Nix {inherit pkgs;}) mkPoetryApplication;
    in {
      packages = {
        seguro-gateway = mkPoetryApplication {
          projectDir = self;
          preferWheels = true;
        };
        default = self.packages.${system}.seguro-gateway;
      };

      devShells.default = pkgs.mkShell {
        inputsFrom = [self.packages.${system}.seguro-gateway];
        packages = [pkgs.poetry];
      };
    });
}