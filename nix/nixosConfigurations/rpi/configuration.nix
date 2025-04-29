# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{ self, ... }:
{
  imports = with self.nixosModules; [
    rpi-base
    gateway
    users
    (fetchTarball {
      url = "https://github.com/nix-community/nixos-vscode-server/tarball/8b6db451de46ecf9b4ab3d01ef76e59957ff549f";
      sha256 = "09j4kvsxw1d5dvnhbsgih0icbrxqv90nzf0b589rb5z6gnzwjnqf";
    })
  ];

  networking = {
    domain = "gateways.seguro.eonerc.rwth-aachen.de";
  };

  services.openssh.enable = true;
  services.vscode-server.enable = true;

  sdImage.populateFirmwareCommands =
    let
      defaultGatewayConfig = "${self}/config/gateway.json";
    in
    ''
      cp ${defaultGatewayConfig} ./firmware

      mkdir -p ./firmware/keys
      cat > ./firmware/keys/README.txt <<EOF
        Please put the gateway specific keys into this directory
      EOF
    '';

  nixpkgs = {
    hostPlatform = "aarch64-linux";
    buildPlatform = "aarch64-linux";
  };

  system.stateVersion = "23.11";
}
