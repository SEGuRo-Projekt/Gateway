# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ pkgs, config, ... }:
let
  cfg = config.seguro.gateway;

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
    runtimeInputs = [ parseTopic ];
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
  environment.systemPackages = with pkgs; [
    listenMeasurements
    mosquitto
    tpm2-tools
  ];

  systemd.services = {
    opcua-mockup = {
      description = "A mockup of an OPC-UA measurement device";
      serviceConfig = {
        ExecStart = "${pkgs.seguro-gateway}/bin/opcua-mockup";
      };
    };
  };
}
