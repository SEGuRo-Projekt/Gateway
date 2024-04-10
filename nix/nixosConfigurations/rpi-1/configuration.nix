# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{ self, lib, ... }:
{
  imports = [
    self.nixosModules.rpi-base
    self.nixosModules.gateway
  ];

  # Copy default Gateway JSON configuration to /boot if it does not exist yet
  sdImage.populateRootCommands =
    let
      defaultGatewayConfig = "${self}/config/gateway.json";
    in
    ''
      cp ${defaultGatewayConfig} ./files/boot
    '';

  nixpkgs = {
    hostPlatform = "aarch64-linux";
    buildPlatform = "x86_64-linux";
  };

  system.stateVersion = "23.11";
}
