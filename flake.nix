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
      url = "github:SEGuRo-Projekt/Platform/dev";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    poetry2nix,
    villas-node,
    ...
  } @ inputs: let
    inherit (builtins) readDir;
    inherit (nixpkgs.lib) mapAttrs;

    dirEntries = path: let
      toPath = n: v: path + "/${n}";
    in
      mapAttrs toPath (readDir path);
    forDirEntries = path: f: mapAttrs f (dirEntries path);
  in
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system};
      p2n = poetry2nix.lib.mkPoetry2Nix {inherit pkgs;};
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
          seguroGatewayConfigTemplate = ./nix/seguro-gateway-config.nix;
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
        seguro-gateway = p2n.mkPoetryApplication {
          projectDir = ./.;
        };
      };

      # A development shell to be used with `nix develop`
      devShells.default = pkgs.mkShell {
        buildInputs = [
          (p2n.mkPoetryEnv {
            projectDir = ./.;
            editablePackageSources = {
              seguro = ./seguro;
            };
          })
        ];

        packages = let
          start-vm = pkgs.writeShellApplication {
            name = "start-vm";
            runtimeInputs = [inputs.nixos-shell.packages.${pkgs.system}.nixos-shell pkgs.swtpm];
            text = ''
              TPMSTATE=$(mktemp -d -t swtpm_XXXX)
              echo "TPM state is at: $TPMSTATE"

              # shellcheck disable=SC2064
              trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

              swtpm socket \
                --tpm2 \
                --tpmstate "dir=$TPMSTATE" \
                --ctrl "type=unixio,path=$TPMSTATE/swtpm-sock" &

              QEMU_OPTS="-chardev socket,id=chrtpm,path=$TPMSTATE/swtpm-sock -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0" \
              nixos-shell --flake .\#vm
            '';
          };
        in (with pkgs // self.packages.${system}; [
          poetry
          reuse
          pre-commit
          nix-render-template
          villas-generate-gateway-config
          start-vm
        ]);
      };
    })
    // {
      nixosModules = let
        dir = ./nix/nixosModules;
        mkNixosModule = name: path: import path;
      in
        forDirEntries dir mkNixosModule;

      nixosConfigurations = let
        dir = ./nix/nixosConfigurations;
        parse = hostname: {
          system,
          modules,
        }: {
          inherit system modules;
          specialArgs = inputs // {inherit hostname;};
        };
        mkNixosConfiguration = name: path:
          nixpkgs.lib.nixosSystem
          (parse name (import path));
      in
        forDirEntries dir mkNixosConfiguration;

      secrets = dirEntries ./nix/secrets;
    };
}
