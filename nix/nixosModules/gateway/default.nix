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

  parseTopic = pkgs.writeShellApplication {
    name = "parse-topic";
    runtimeInputs = with pkgs; [ jq ];
    text = ''
      jq -r '.[]
      | try to_entries[]
      | select(.key | try startswith("mqtt"))
      | .value.out.publish' ${cfg.villasConfigPath}
    '';

  };

  listenMeasurements = pkgs.writeShellApplication {
    name = "listen-measurements";
    runtimeInputs = with pkgs; [ parseTopic ];
    text = ''
      protobuf-subscriber \
      --host ${cfg.mqtt.host} \
      --port ${toString cfg.mqtt.port} \
      --cafile ${cfg.tls.caCert} \
      --cert ${cfg.tls.cert} \
      --key ${cfg.tls.key} \
      --topic "$(parse-topic)" \
      --id "$HOSTNAME"-sub
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

    environment.systemPackages = with pkgs; [
      villas-node
      seguro-platform
      seguro-gateway
      mosquitto
      tpm2-tools
      villas-generate-gateway-config
      listenMeasurements
    ];

    services = {
      villas.node = {
        enable = true;
        configPath = cfg.villasConfigPath;
        package = pkgs.villas-node;
      };

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

            ConditionPathExists = with cfg; [
              gatewayConfigPath

              tls.caCert
              tls.key
              tls.cert
            ];

            ExecStartPre = "${generateVillasConfigScript}/bin/villas-generate-config";
            ExecStart = lib.mkForce "${config.services.villas.node.package}/bin/villas-node ${config.services.villas.node.configPath}";
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

        opcua-mockup = {
          description = "A mockup of an OPC-UA measurement device";
          serviceConfig = {
            ExecStart = "${pkgs.seguro-gateway}/bin/opcua-mockup";
          };
        };
      };

      sockets = {
        seguro-signature-sender = {
          description = "Sign measurement data via TSA and TPM and publish them via MQTT";
          wantedBy = [ "multi-user.target" ];
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
