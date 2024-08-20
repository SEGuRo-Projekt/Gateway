# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
# A NixOS module which configures VILLASnode
# for the SEGuRo Gateways:
#  - Starts VILLASnode at boot
#  - Copies default Gateway JSON configuration to /boot
#  - Generates VILLASnode config via villas-generate-gateway-config during start of VILLASnode
#  - Makes sure opcua-readout and villas-generate-gateway-config are in the system PATH
{
  pkgs,
  lib,
  config,
  ...
}@inputs:
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

        csr = mkOption {
          type = types.path;
          default = "/boot/firmware/keys/mp.csr";
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
    nixpkgs.overlays = [
      inputs.villas-node.overlays.default
      (final: prev: { villas-node = prev.villas-node.override { withNodeRedis = false; withNodeWebrtc = false; withNodeEthercat = false; }; })
    ];

    environment.systemPackages = with pkgs; [
      villas-node
      seguro-platform
      seguro-gateway
      seguro-generate-keys
      mosquitto
      tpm2-tools
      villas-generate-gateway-config
    ];

    services.villas.node = {
      enable = true;
      configPath = cfg.villasConfigPath;
      package = pkgs.villas-node;
    };

    systemd = {
      globalEnvironment = {
        MQTT_HOST = cfg.mqtt.host;
        MQTT_PORT = toString cfg.mqtt.port;

        TLS_KEY = cfg.tls.key;
        TLS_CSR = cfg.tls.csr;
        TLS_CERT = cfg.tls.cert;
        TLS_CACERT = cfg.tls.caCert;
      };

      services = {
        # Extend villas-node SystemD service to generate VILLASnode config
        # in ExecPreStart
        villas-node = lib.mkIf config.services.villas.node.enable {
          path = [ pkgs.seguro-gateway ];
          serviceConfig = {
            Restart = "on-failure";
            RestartSec = 3;
            RestartSteps = 16;
            RestartMaxDelaySec = 3600;

            ExecStartPre = "${generateVillasConfigScript}/bin/villas-generate-config";
            ExecStart = lib.mkForce "${config.services.villas.node.package}/bin/villas-node ${config.services.villas.node.configPath}";
          };

          unitConfig = {
            ConditionPathExists = with cfg; [
              gatewayConfigPath

              tls.caCert
              tls.key
              tls.cert
            ];
          };
        };

        seguro-heartbeat-sender = {
          description = "Publish the device status periodically via MQTT";
          startAt = "*-*-* *:*:00/10"; # Run every 10-minutes
          serviceConfig = {
            ExecStart = "${pkgs.seguro-platform}/bin/heartbeat-sender";
          };
        };

        seguro-signature-sender = {
          description = "Sign measurement data via TSA and TPM and publish them via MQTT";
          serviceConfig = {
            StandardInput = "socket";
            ExecStart = "${pkgs.seguro-platform}/bin/signature-sender --fifo /dev/stdin";
          };
        };

        seguro-opcua-mockup = {
          enable = false;

          description = "A mockup of an OPC-UA measurement device";
          serviceConfig = {
            ExecStart = "${pkgs.seguro-gateway}/bin/opcua-mockup";
          };
        };

        seguro-generate-keys = {
          description = "Generate measurement device specific keys during first boot";
          unitConfig = {
            ConditionPathExists = with cfg; [
              "!${tls.csr}"
              "!${tls.key}"
              "!${tls.cert}"
            ];
          };

          serviceConfig={
            ExecStart = "${lib.getExe pkgs.seguro-generate-keys}";
          };

          wantedBy = [
            "multi-user.target"
          ];
        };
      };

      sockets = {
        seguro-signature-sender = {
          description = "Sign measurement data via TSA and TPM and publish them via MQTT";
          socketConfig = {
            ListenFIFO = "/run/villas-digests.fifo";
          };
        };
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
