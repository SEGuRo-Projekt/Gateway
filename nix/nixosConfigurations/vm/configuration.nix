# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{self, ...}: {
  imports = [
    self.nixosModules.gateway
  ];

  nixos-shell.mounts = {
    mountHome = false;
    mountNixProfile = false;
  };

  # Copy default Gateway JSON configuration to /boot if it does not exist yet
  system.activationScripts.defaultGatewayConfig.text = let
    defaultGatewayConfig = "${self}/config/gateway.json";
  in ''
    if ! [ -f /boot/gateway.json ]; then
      cp ${defaultGatewayConfig} /boot/gateway.json
    fi
  '';

  networking.extraHosts = ''
    10.0.2.2 host # The VM host / gateway
  '';

  systemd.services.villas-node = {
    environment = {
      DEMO_DATA = "true";
      MQTT_HOST = "host";
      # DEBUG = "true";
    };
  };

  system.stateVersion = "23.11";
}
