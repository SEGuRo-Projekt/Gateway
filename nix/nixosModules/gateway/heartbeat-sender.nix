# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ pkgs, config, ... }:
let
  cfg = config.seguro.gateway;
in
{
  systemd.services = {
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
  };
}
