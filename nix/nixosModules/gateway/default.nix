# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
# A NixOS module which configures VILLASnode
# for the SEGuRo Gateways:
#  - Starts VILLASnode at boot
#  - Copies default Gateway JSON configuration to /boot
#  - Generates VILLASnode config via villas-generate-gateway-config during start of VILLASnode
#  - Makes sure readout_umg and villas-generate-gateway-config are in the system PATH
{
  pkgs,
  self,
  ...
} @ inputs: let
  platform = inputs.seguro-platform.packages.${pkgs.system}.seguro-platform;
  villas-node = inputs.villas-node.packages.${pkgs.system}.villas;

  myPkgs = self.packages.${pkgs.system};

  gatewayConfigPath = "/boot/gateway.json";
  villasConfigPath = "/boot/villas-node.json";

  generateVillasConfigScript = pkgs.writeShellApplication {
    name = "villas-generate-config";
    runtimeInputs = [
      myPkgs.villas-generate-gateway-config
    ];
    text = ''
      villas-generate-gateway-config < ${gatewayConfigPath} > ${villasConfigPath}
    '';
  };
in {
  imports = [
    inputs.villas-node.nixosModules.default
  ];

  environment.systemPackages = with pkgs // myPkgs; [
    platform
    villas-node
    mosquitto
    tpm2-tools
    villas-generate-gateway-config
  ];

  services.villas.node = {
    enable = true;
    configPath = villasConfigPath;
  };

  systemd = {
    services = {
      # Extend villas-node SystemD service to generate VILLASnode config
      # in ExecPreStart
      villas-node = {
        path = [
          myPkgs.seguro-gateway
        ];
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
          ExecStart = "${platform}/bin/heartbeat-sender";
        };
      };

      seguro-signature-sender = {
        description = "Sign measurement data via TSA and TPM and publish them via MQTT";
        serviceConfig = {
          StandardInput = "socket";
          ExecStart = "${platform}/bin/signature-sender --fifo /dev/stdin";
        };
      };
    };

    sockets = {
      seguro-signature-sender = {
        enable = true;
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
      experimental-features = ["nix-command" "flakes"];
    };
    gc.automatic = true;
  };
}
