# SPDX-FileCopyrightText: 2026 Felix Wege, EONERC-ACS, RWTH Aachen University
# SPDX-License-Identifier: Apache-2.0

inputs:
{ lib, config, pkgs, ... }:
let
  cfg = config.services.gateway.autoUpgrade;
in
{
  options.services.gateway.autoUpgrade = {
    enable = lib.mkEnableOption "automatic gateway updates via system.autoUpgrade";
    flake = lib.mkOption {
      type = lib.types.str;
      default = "git+ssh://git@github.com/SEGuRo-Projekt/Gateway.git?ref=main#gateway-rpi";
      description = "Flake reference to track for updates.";
    };
    dates = lib.mkOption {
      type = lib.types.str;
      default = "02:00";
    };
    randomizedDelaySec = lib.mkOption {
      type = lib.types.str;
      default = "5min";
    };
  };

  config = lib.mkIf cfg.enable {
    system.autoUpgrade = {
      enable = true;
      inherit (cfg) flake dates randomizedDelaySec;
      flags = [ "--no-update-lock-file" ];
    };
  };
}
