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
  ...
}@inputs:
let
  gatewayConfigPath = "/boot/gateway.json";
  villasConfigPath = "/boot/villas-node.json";

  generateVillasConfigScript = pkgs.writeShellApplication {
    name = "villas-generate-config";
    runtimeInputs = with pkgs; [ villas-generate-gateway-config ];
    text = ''
      villas-generate-gateway-config < ${gatewayConfigPath} > ${villasConfigPath}
    '';
  };
in
{
  imports = [ inputs.villas-node.nixosModules.default ];

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
    mosquitto
    tpm2-tools
    villas-generate-gateway-config
  ];

  services.villas.node = {
    enable = false;
    configPath = villasConfigPath;
    package = pkgs.villas;
  };

  systemd = {
    services = {
      # Extend villas-node SystemD service to generate VILLASnode config
      # in ExecPreStart
      villas-node = {
        path = [ pkgs.seguro-gateway ];
        serviceConfig = {
          Restart = "on-failure";
          RestartSec = 3;
          RestartSteps = 16;
          RestartMaxDelaySec = 3600;

          ConditionPathExists = gatewayConfigPath;
          ExecStartPre = "${generateVillasConfigScript}/bin/villas-generate-config";
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
        enable = false;

        description = "A mockup of an OPC-UA measurement device";
        serviceConfig = {
          ExecStart = "${pkgs.seguro-gateway}/bin/opcua-mockup";
        };
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
}
