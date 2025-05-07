# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.seguro.gateway;
in
{
  systemd.services = {
    set-hostname = {
      description = "Set the hostname early during boot";

      requires = [ "boot-firmware.mount" ];
      after = [ "boot-firmware.mount" ];

      wantedBy = [ "network-pre.target" ];
      before = [ "network-pre.target" ];

      unitConfig = {
        ConditionPathExists = [ cfg.gatewayConfigPath ];
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
}
