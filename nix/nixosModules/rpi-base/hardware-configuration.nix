# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{ lib, ... }:
{
  boot = {
    # loader.systemd-boot.enable = true;
  };

  # Default NixOS sd image partitioning
  fileSystems = {
    # Mount tmpfs as root
    # "/" = {
    #   device = "none";
    #   fsType = "tmpfs";
    #   options = ["size=2G" "mode=755"];
    # };

    # Mount the firmware partition into /boot
    "/boot/firmware" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = lib.mkForce [
        "auto"
        "nofail"
      ];
    };

    # Mount the rest of the partition as persistent storage
    # "/persistent" = {
    #   device = "/dev/disk/by-label/NIXOS_SD";
    #   fsType = "ext4";
    #   neededForBoot = true;
    # };

    # Mount /nix from persistent storage
    # "/nix" = {
    #   depends = ["/persistent"];
    #   device = "/persistent/nix";
    #   fsType = "none";
    #   options = ["bind"];
    # };

    # Mount /boot from persistent storage
    # "/boot" = {
    #   depends = ["/persistent"];
    #   device = "/persistent/boot";
    #   fsType = "none";
    #   options = ["bind"];
    # };
  };

  security.tpm2 = {
    enable = true;
    tctiEnvironment.enable = true;
  };

  networking.useDHCP = true;
  nixpkgs.hostPlatform = "aarch64-linux";
}
