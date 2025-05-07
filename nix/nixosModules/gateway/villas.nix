# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  pkgs,
  config,
  lib,
  inputs,
  ...
}:
let
  cfg = config.seguro.gateway;

  generateVillasConfigScript = pkgs.writeShellApplication {
    name = "villas-generate-config";
    runtimeInputs = with pkgs; [ villas-generate-gateway-config ];
    text = ''
      villas-generate-gateway-config < ${cfg.gatewayConfigPath} > ${cfg.villasConfigPath}
    '';
  };
in
{
  imports = [ inputs.villas-node.nixosModules.default ];

  environment.systemPackages = with pkgs; [
    villas-node
    villas-generate-gateway-config
  ];

  nixpkgs.overlays = [
    inputs.villas-node.overlays.default
    # TODO: Cross-build of hiredis is broken
    (final: prev: { villas-node = prev.villas-node.override { withNodeRedis = false; }; })

    # TODO: Enable EtherCAT on aarch64
    (final: prev: {
      ethercat = prev.ethercat.overrideAttrs (
        finalAttrs: previousAttrs: {
          meta = previousAttrs.meta or { } // {
            platforms = prev.lib.platforms.linux;
          };
        }
      );
    })
  ];

  services = {
    villas.node = {
      enable = true;
      configPath = cfg.villasConfigPath;
      package = pkgs.villas-node;
    };
  };

  systemd = {
    services = {
      # Extend villas-node SystemD service to generate VILLASnode config
      # in ExecPreStart
      villas-node = lib.mkIf config.services.villas.node.enable {
        path = [ pkgs.seguro-gateway ];

        requires = [
          "network-online.target"
          "cert-renewal.service"
          "seguro-signature-sender.socket"
          "boot-firmware.mount"
        ];
        after = [
          "network-online.target"
          "cert-renewal.service"
          "seguro-signature-sender.socket"
          "boot-firmware.mount"
        ];
        wantedBy = [ "multi-user.target" ];

        unitConfig = {
          ConditionPathExists = with cfg; [
            gatewayConfigPath

            tls.caCert
            tls.key
            tls.cert
          ];
        };

        serviceConfig = {
          Restart = "on-failure";
          RestartSec = 3;
          RestartSteps = 16;
          RestartMaxDelaySec = 3600;
          TimeoutStopSec = 5;

          ExecStartPre = "${generateVillasConfigScript}/bin/villas-generate-config";
          ExecStart = lib.mkForce "${config.services.villas.node.package}/bin/villas-node ${config.services.villas.node.configPath}";
        };
      };

      seguro-signature-sender = {
        description = "Sign measurement data via TSA and TPM and publish them via MQTT";

        requires = [
          "network-online.target"
          "cert-renewal.service"
        ];
        after = [
          "network-online.target"
          "cert-renewal.service"
        ];

        unitConfig = {
          ConditionPathExists = with cfg; [
            tls.caCert
            tls.key
            tls.cert
          ];
        };

        serviceConfig = {
          StandardInput = "socket";
          StandardOutput = "journal";
          ExecStart = "${pkgs.seguro-platform}/bin/signature-sender --fifo /dev/stdin";
        };
      };
    };

    sockets = {
      seguro-signature-sender = {
        description = "Sign  measurement data via TSA and TPM and publish them via MQTT";
        socketConfig = {
          ListenFIFO = "/run/villas-digests.fifo";
        };
      };
    };
  };
}
