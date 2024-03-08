# SPDX-FileCopyrightText: 2024 OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  description = "The measurement device gateway for SEGuRo";

  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
    poetry2nix = {
      url = "github:nix-community/poetry2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    villas-node.url = "github:VILLASframework/node/nixos-module-config-path";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
    villas-node,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      p2n = poetry2nix.lib.mkPoetry2Nix {inherit pkgs;};
      inherit (p2n) mkPoetryApplication;
    in rec {
      packages = {
        # A simple shell script which transforms one JSON file into another using
        # a Nix function.
        #
        # The input JSON file is read from stdin.
        # The output JSON file is written to stdout.
        # The file containing the Nix function is passed as the first argument.
        nix-render-template = pkgs.writeShellApplication {
          name = "nix-render-template";
          runtimeInputs = with pkgs; [
            nix
            jq
          ];

          text = ''
            # shellcheck disable=SC1083
            nix --extra-experimental-features nix-command \
              eval \
                --json \
                --file "$1" \
                --apply 'let
                    nixpkgs = import ${nixpkgs} {};
                    stdin = builtins.readFile /dev/stdin;
                  in f: f {
                    lib = nixpkgs.lib;
                    config = builtins.fromJSON stdin;
                  }' \
            | jq
          '';
        };

        # A simple shell script which uses nix-render-template
        # to transform a SEGuRo Gateway JSON configuration file into
        # a VILLASnode JSON configuration file.
        #
        # The SEGuRo Gateway JSON configuration file is read from stdin.
        # The VILLASnode JSON configuration file is written to stdout.
        villas-generate-gateway-config = let
          seguroGatewayConfigTemplate = ./seguro-gateway-config.nix;
        in
          pkgs.writeShellApplication {
            name = "villas-generate-gateway-config";
            runtimeInputs = [
              packages.nix-render-template
            ];

            text = "nix-render-template ${seguroGatewayConfigTemplate}";
          };

        # A Python / Poetry application used for getting data from
        # Janitza UMG measurement devices via OPC-UA.
        # This application is used by VILLASnode exec-node type.
        seguro-gateway = mkPoetryApplication {
          projectDir = self;
          preferWheels = true;
        };
      };

      # A development shell to be used with `nix develop`
      devShells.default = pkgs.mkShell {
        inputsFrom = [
          self.packages.${system}.seguro-gateway
        ];
        shellHook = ''
          export QEMU_KERNEL_PARAMS=console=ttyS0
        '';

        packages =
          (with pkgs; [
            poetry
            reuse
            pre-commit
          ])
          ++ (with self.packages.${system}; [
            nix-render-template
            villas-generate-gateway-config
          ])
          ++ [
            (pkgs.writeShellApplication
              {
                name = "start-vm";
                text = ''
                  set -e

                  nixos-rebuild --flake .\#default build-vm
                  ./result/bin/run-nixos-vm -nographic
                  reset
                '';
              })
          ];
      };
    })
    // {
      nixosModules = rec {
        default = gateway;

        # A NixOS module which configures VILLASnode
        # for the SEGuRo Gateways:
        #  - Starts VILLASnode at boot
        #  - Copies default Gateway JSON configuration to /boot
        #  - Generates VILLASnode config via villas-generate-gateway-config during start of VILLASnode
        #  - Makes sure readout_umg and villas-generate-gateway-config are in the system PATH
        gateway = {
          inputs,
          lib,
          pkgs,
          config,
          ...
        }: let
          mypkgs = self.packages.${pkgs.system};

          gatewayConfigPath = "/boot/gateway.json";
          villasConfigPath = "/boot/villas-node.json";

          defaultGatewayConfig = ./config/opc-ua.json;

          generateVillasConfigScript = pkgs.writeShellApplication {
            name = "villas-generate-config";
            runtimeInputs = [
              mypkgs.villas-generate-gateway-config
            ];
            text = ''
              villas-generate-gateway-config < ${gatewayConfigPath} > ${villasConfigPath}
            '';
          };
        in {
          imports = [
            inputs.villas-node.nixosModules.default
          ];

          environment.systemPackages = [
            mypkgs.seguro-gateway
            mypkgs.villas-generate-gateway-config
          ];

          services.villas.node = {
            enable = true;
            configPath = villasConfigPath;
          };

          # Extend villas-node SystemD service to generate VILLASnode config
          # in ExecPreStart
          systemd.services.villas-node = {
            path = [
              mypkgs.seguro-gateway
            ];
            serviceConfig = {
              ConditionPathExists = config.services.villas.node.configPath;
              ExecStartPre = "${generateVillasConfigScript}/bin/villas-generate-config";
            };
          };

          # Copy default Gateway JSON configuration to /boot if it does not exist yet
          system.activationScripts.copyDefaultGatewayConfig = ''
            if ! [ -f ${gatewayConfigPath} ]; then
              cp ${defaultGatewayConfig} ${gatewayConfigPath}
            fi
          '';
        };
      };

      # A simple NixOS configuration for testing the gateway in a VM
      #
      # Start via
      nixosConfigurations = {
        default = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ({self, ...}: {
              imports = [
                self.nixosModules.gateway
              ];

              boot.loader = {
                systemd-boot.enable = true;
                efi.canTouchEfiVariables = true;
              };

              users.users.villas = {
                isNormalUser = true;
                extraGroups = ["wheel"];
                initialPassword = "villas";
              };

              system.stateVersion = "23.11";
            })
          ];
          specialArgs = {
            inherit self;
            inherit inputs;
          };
        };
      };
    };
}
