# SPDX-FileCopyrightText: 2024 Philipp Jungkamp, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib) escapeShellArg getExe;
  nix = getExe config.nix.package;
  nixos-rebuild = getExe pkgs.nixos-rebuild;
  cfg = config.seguro.auto-update;
  host = config.networking.hostName;
in {
  options.seguro.auto-update = with lib; {
    enable = mkEnableOption "SEGuRo auto-update";

    dates = mkOption {
      type = types.str;
      default = "daily";
      description = mdDoc ''
        How often or when the automatic update is performed.

        The format is described in {manpage}`systemd.time(7)`.
      '';
    };

    flake = mkOption {
      type = types.str;
      default = "github:SEGuRo-Projekt/Nixfiles/master";
      description = mkdDoc ''
        The remote flake from which the system should try to
        rebuild itself.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd = {
      timers.seguro-auto-update = {
        wantedBy = ["timers.target"];
        timerConfig = {
          OnCalendar = cfg.dates;
          Unit = "seguro-auto-update.service";
        };
      };

      services.seguro-auto-update = {
        script = ''
          current="$(readlink /run/current-system)"
          remote="$(${nix} eval --raw --refresh ${
            escapeShellArg ''${cfg.flake}#nixosConfigurations."${host}".config.system.build.toplevel''
          })"

          if [ "$current" != "$remote" ]; then
            echo "The remote nixos configuration for this machine has changed"
            echo "current: $current"
            echo "remote:  $remote"

            ${nixos-rebuild} boot --flake ${
            escapeShellArg "${cfg.flake}#${host}"
          }

            systemctl reboot
          fi
        '';
        serviceConfig = {
          Type = "oneshot";
          User = "root";
        };
      };
    };
  };
}
