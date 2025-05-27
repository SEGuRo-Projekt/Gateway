# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
# A NixOS module which configures VILLASnode
# for the SEGuRo Gateways:
#  - Starts VILLASnode at boot
#  - Copies default Gateway JSON configuration to /boot
#  - Generates VILLASnode config via villas-generate-gateway-config during start of VILLASnode
#  - Makes sure opcua-readout and villas-generate-gateway-config are in the system PATH
{
  self,
  pkgs,
  lib,
  config,
  inputs,
  ...
}:
let
  cfg = config.seguro.gateway;
in
{
  imports = with self.nixosModules; [
    inputs.nixos-vscode-server.nixosModules.default

    users

    ./cert-renewal.nix
    ./provision.nix
    ./heartbeat-sender.nix
    ./tools.nix
    ./villas.nix
  ];

  options = with lib; {
    seguro.gateway = {

      tls = {
        key = mkOption {
          type = types.path;
          default = "/boot/firmware/keys/mp.key";
        };

        cert = mkOption {
          type = types.path;
          default = "/boot/firmware/keys/mp.crt";
        };

        caCert = mkOption {
          type = types.path;
          default = "/boot/firmware/keys/ca.crt";
        };
      };

      mqtt = {
        host = mkOption {
          type = types.str;
          default = "seguro.eonerc.rwth-aachen.de";
        };

        port = mkOption {
          type = types.port;
          default = 8883;
        };
      };

      gatewayConfigPath = mkOption {
        type = types.path;
        default = "/boot/firmware/gateway.json";
      };

      villasConfigPath = mkOption {
        type = types.path;
        default = "/tmp/villas-node.json";
      };
    };
  };

  config = {
    time.timeZone = "Europe/Berlin";

    networking = {
      domain = "gateways.seguro.eonerc.rwth-aachen.de";
    };

    environment.systemPackages = with pkgs; [
      seguro-platform
      seguro-gateway
    ];

    services = {
      openssh.enable = true;
      vscode-server.enable = true;

      getty = {
        greetingLine = lib.mkForce ''<<< Welcome to the SEGuRo Gateway OS ${config.system.nixos.label} (\m) - \l >>>'';
        helpLine = lib.mkForce "\nPlease visit the SEGuRo online documentation for support: https://seguro.eonerc.rwth-aachen.de/";
      };
    };

    systemd = {
      globalEnvironment = {
        MQTT_HOST = cfg.mqtt.host;
        MQTT_PORT = toString cfg.mqtt.port;

        TLS_KEY = cfg.tls.key;
        TLS_CERT = cfg.tls.cert;
        TLS_CACERT = cfg.tls.caCert;
      };
    };

    security.tpm2 = {
      enable = true;
      tctiEnvironment.enable = true;
    };

    nix = {
      settings = {
        experimental-features = [
          "nix-command"
          "flakes"
        ];
      };
      gc.automatic = true;
    };
  };
}
