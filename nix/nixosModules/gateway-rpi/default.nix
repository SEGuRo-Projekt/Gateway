# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  self,
  ...
}@inputs:
{ config, ... }:
{
  imports = with self.nixosModules; [
    rpi-base
    gateway
  ];

  sdImage.populateFirmwareCommands =
    let
      inherit (builtins) baseNameOf;

      cfg = config.seguro.gateway;

      defaultGatewayConfig = "${self}/config/gateway.json";
    in
    ''
      cp ${defaultGatewayConfig} ./firmware

      mkdir -p ./firmware/keys
      cat > ./firmware/keys/README.txt <<EOF
      Please put the gateway specific key and certificate into this directory and name them:

      - Key:             ${baseNameOf cfg.tls.key}
      - Certificate:     ${baseNameOf cfg.tls.cert}
      - CA Certificates: ${baseNameOf cfg.tls.caCert}
      EOF
    '';

  nixpkgs = {
    hostPlatform = "aarch64-linux";
    buildPlatform = "aarch64-linux";
  };

  system.stateVersion = "23.11";
}
