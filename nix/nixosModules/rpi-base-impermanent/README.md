# Raspberry Pi Shared Base Configuration

- SPDX-FileCopyrightText: 2024 Philipp Jungkamp, OPAL-RT Germany GmbH
- SPDX-License-Identifier: Apache-2.0

This configuration assumes:
- The SD card is partitioned like the nixos-aarch64-install-image.
- All files in on the SD card are world readable.
- The rootfs is a tmpfs build up from bind mounts and symlinks to persistent storage.
- RPIBOOT verifies and boots our uboot using the RPi 4Bs secure boot feature.
- Our uboot uses the tpm2 to verify the rest of the boot chain.

The rough idea is based on the [description] and [howto] for the secureboot feature,
as well as the integration of a TPM into the boot process outlined in [rpi4-uboot-tpm].

[description]: https://pip.raspberrypi.com/categories/685-whitepapers-app-notes/documents/RP-004651-WP/Raspberry-Pi-4-Boot-Security.pdf
[howto]: https://pip.raspberrypi.com/categories/685-whitepapers-app-notes/documents/RP-003466-WP/Boot-Security-Howto.pdf
[rpi4-uboot-tpm]: https://github.com/joholl/rpi4-uboot-tpm


## TODO

- Evaluate where in the `secrets.nix` a value of `allSystems` is acceptable as breaching a single machine compromises a secret used by many others.
- The secret key should be created on the LUKS volume and should thus guarded by our TPM.


## Building our own image with firmware for secureboot

- Use the [sd-image.nix] module from nixpkgs for the basic image generation.
- Override the [ubootRaspberryPi4_64bit] derivation with a custom defconfig that enables tpm2 support.
- Generate our own firmware partition contents similar to [sd-image-aarch64.nix]. (custom `config.txt` + our modified uboot)
- Our /nix and /boot directories stay unencrypted on the sd-card.
- Copy and modify the [enpandOnBoot] code to ...
  - ... only grow root to a specific size (e.g. 20GB TBD)
  - ... add another new LUKS encrypted partition with a key derived from the TPM2 for secrets and logs.

[expandOnBoot]: https://github.com/NixOS/nixpkgs/blob/b8d6d842d086ba02d79b7bc138b9f09c78864205/nixos/modules/installer/sd-card/sd-image.nix#L258-L283
[sd-image.nix]: https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/installer/sd-card/sd-image.nix
[sd-image-aarch64.nix]: https://github.com/NixOS/nixpkgs/blob/af421ccb0ab04bf1b7b0f8f73ca278e5863f63a4/nixos/modules/installer/sd-card/sd-image-aarch64.nix#L21-L81
[ubootRaspberryPi4_64bit]: https://github.com/NixOS/nixpkgs/blob/b8d6d842d086ba02d79b7bc138b9f09c78864205/pkgs/misc/uboot/default.nix#L474-L478


## Configuring a custom U-Boot with SPI TPM support

Check out the instructions in [rpi-uboot-tpm#setting-up-and-configuring] on GitHub.

[rpi-uboot-tpm#setting-up-and-configuring]: https://github.com/joholl/rpi4-uboot-tpm#setting-up-and-configuring
