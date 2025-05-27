# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) concatStringsSep;

  cfg = config.services.cert-renewal;

  checkRenewScript = pkgs.writeShellApplication {
    name = "check-cert-renewal";
    runtimeInputs = with pkgs; [
      systemd
      openssl
    ];
    text = ''
      CURRENT_TIME=$(date +%s)
      if ! [ -f "$CERT" ] || ! [ -f "$KEY" ]; then
        EXPIRY_TIME=0
      else
        EXPIRY_TIME=$(openssl x509 -enddate -noout -in "$CERT" | cut -d = -f 2- | date +%s -f - || echo 0)
      fi

      if (( EXPIRY_TIME - CURRENT_TIME < RENEW_BEFORE )); then
        echo "Renewing certificate"
        ${lib.getExe pkgs.cert-renewal}
        systemctl restart ${concatStringsSep " " cfg.restartServices}
      else
        echo "Certificate is still valid"
      fi
    '';
  };
in
{
  options = {
    services.cert-renewal = {
      enable = lib.mkEnableOption "Enable certificate renewal via EST";

      estUrl = lib.mkOption {
        type = lib.types.str;
        description = "Endpoint for the EST server";
      };
      commonName = lib.mkOption {
        type = lib.types.str;
        default = config.networking.hostName;
        description = "Common name for the certificate";
      };
      renewBefore = lib.mkOption {
        type = lib.types.int;
        default = 3 * 60 * 60 * 24;
        description = "Renew the certificate if it expires in less than this many seconds";
      };
      restartServices = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [
          "villas-node.service"
          "seguro-signature-sender.service"
        ];
        description = "List of services to restart after certificate renewal";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.cert-renewal = {
      description = "Certificate renewal via EST";
      startAt = "*:0/5";

      requires = [ "network-online.target" ];
      after = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment = {
        CERT = cfg.cert;
        KEY = cfg.key;
        EST_URL = cfg.estEndpoint;
        RENEW_BEFORE = toString cfg.renewBefore;
        CSR_COMMON_NAME = cfg.commonName;
      };

      serviceConfig = {
        Type = "oneshot";

        ExecStart = lib.getExe checkRenewScript;
      };
    };
  };
}
