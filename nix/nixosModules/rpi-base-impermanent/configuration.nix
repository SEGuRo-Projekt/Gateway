# SPDX-FileCopyrightText: 2024 Philipp Jungkamp, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  hostname,
  impermanence,
  ...
}: {
  imports = [
    impermanence.nixosModules.impermanence
  ];

  networking.hostName = hostname;

  environment = {
    # Store persistent state on the SD card mounted at /persist
    #
    # Only few kinds of state are persistent, namely:
    # - logs: /var/log /etc/machine_id
    # - coredumps: /var/lib/systemd/coredump
    # - private keys: /var/lib/keys
    persistence."/persistent" = {
      hideMounts = true;
      directories = [
        {
          directory = "/var/lib/keys";
          mode = "700";
        }
        "/var/log"
        "/var/lib/nixos"
        "/var/lib/systemd/coredump"
      ];
      files = [
        "/etc/machine-id"
      ];
    };
  };
}
