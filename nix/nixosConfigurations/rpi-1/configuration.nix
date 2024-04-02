# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{self, ...}: {
  imports = [
    self.nixosModules.rpi-base
    self.nixosModules.gateway
  ];

  # Copy default Gateway JSON configuration to /boot if it does not exist yet
  sdImage.populateRootCommands = let
    defaultGatewayConfig = "${self}/config/gateway.json";
  in ''
    cp ${defaultGatewayConfig} ./files/boot
  '';

  system.stateVersion = "23.11";
}
