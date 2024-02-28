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
    villas-node.url = "github:VILLASframework/node";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
    villas-node,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      inherit (poetry2nix.lib.mkPoetry2Nix {inherit pkgs;}) mkPoetryApplication;
    in {
      packages = {
        villas-config-generator = pkgs.writeShellApplication {
          name = "villas-config-generator";
          runtimeInputs = with pkgs; [
            nix
            jq
          ];

          text = ''
            nix eval --json --file villas-config-generator.nix --apply 'f: f (builtins.fromJSON (builtins.readFile /dev/stdin))' | jq
          '';
        };

        seguro-gateway = mkPoetryApplication {
          projectDir = self;
          preferWheels = true;
        };
        default = self.packages.${system}.seguro-gateway;
      };

      devShells.default = pkgs.mkShell {
        inputsFrom = [
          self.packages.${system}.seguro-gateway
        ];
        packages = with pkgs; [
          poetry
          reuse
          pre-commit
        ];
      };

      nixosModules = rec {
        default = measurement-device;
        measurement-device = {
          inputs,
          lib,
          config,
          ...
        }: let
          gatewayConfig = /boot/gateway.json;
          villasConfig = /tmp/villas-node.json;

          generateVillasConfigScript = pkgs.writeShellApplication {
            name = "villas-generate-config";
            runtimeInputs = [
              self.packages.villas-config-generator
            ];
            text = ''
              villas-config-generator < ${gatewayConfig} > ${villasConfig}
            '';
          };
        in {
          imports = [
            villas-node.nixosModules.villas-node
          ];

          services.villas.node = {
            enable = true;
            configPath = "/tmp/villas-node.json";
          };

          # Convert simplified gateway config to VILLASnode configuration.
          systemd.services.villas-node = {
            serviceConfig = {
              ConditionPathExists = config.villas.node.configPath;
              ExecStartPre = "${generateVillasConfigScript}/bin/villas-generate-config";
            };
          };
        };
      };
    });
}
