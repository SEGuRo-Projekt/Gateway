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

        seguro-heartbeat-sender = {
          description = "Publish the device status periodically via MQTT";

          requires = [
            "network-online.target"
            "cert-renewal.service"
          ];
          after = [
            "network-online.target"
            "cert-renewal.service"
          ];
          wantedBy = [ "multi-user.target" ];

          startAt = "*:*:0/10"; # Run every 10-seconds

          unitConfig = {
            ConditionPathExists = with cfg; [
              tls.caCert
              tls.key
              tls.cert
            ];
          };

          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.seguro-platform}/bin/heartbeat-sender";
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

        opcua-mockup = {
          description = "A mockup of an OPC-UA measurement device";
          serviceConfig = {
            ExecStart = "${pkgs.seguro-gateway}/bin/opcua-mockup";
          };
        };

        cert-renewal = {
          description = "EST renewal of certificats using curl";
          startAt = "*:0/5";

          requires = [ "network-online.target" ];
          after = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];

          serviceConfig = {
            Type = "oneshot";

            ExecStart = lib.getExe (
              pkgs.writeShellApplication {
                name = "cert-renewal-service";
                runtimeInputs = [
                  pkgs.systemd
                  pkgs.openssl
                ];
                text = ''
                  CURRENT_TIME=$(date +%s)
                  if [[ ! -f "${cfg.tls.cert}" || ! -f "${cfg.tls.key}" ]]; then
                    EXPIRY_TIME=0
                  else
                    EXPIRY_TIME=$(openssl x509 -enddate -noout -in "${cfg.tls.cert}" | cut -d = -f 2- | date +%s -f - || echo 0)
                  fi

                  if (( EXPIRY_TIME - CURRENT_TIME < 3*60*60*24 )); then
                    echo "Renewing certificate"
                    ${lib.getExe pkgs.cert-renewal} "${cfg.tls.cert}" "${cfg.tls.key}"
                    systemctl restart villas-node seguro-signature-sender

                  else
                    echo "Certificate is still valid"
                  fi
                '';
              }
            );
          };
        };

        set-hostname = {
          description = "Set the hostname early during boot";

          requires = [ "boot-firmware.mount" ];
          after = [ "boot-firmware.mount" ];

          wantedBy = [ "network-pre.target" ];
          before = [ "network-pre.target" ];

          unitConfig = {
            ConditionPathExists = [
              cfg.gatewayConfigPath
            ];
          };

          serviceConfig = {
            Type = "oneshot";

            ExecStart = lib.getExe (
              pkgs.writeShellApplication {
                name = "set-hostname";
                runtimeInputs = [ pkgs.jq ];
                text = ''
                  HOSTNAME=$(jq -r '.uid' ${cfg.gatewayConfigPath})
                  echo "$HOSTNAME" > /etc/hostname
                  hostnamectl set-hostname --transient "$HOSTNAME"
                '';
              }
            );
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
