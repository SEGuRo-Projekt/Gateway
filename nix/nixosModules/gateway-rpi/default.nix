# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ self, ... }:
{
  imports = with self.nixosModules; [
    rpi-base
    gateway
  ];

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
