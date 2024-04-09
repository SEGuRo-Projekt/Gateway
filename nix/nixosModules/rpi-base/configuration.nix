# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  hostname,
  modulesPath,
  lib,
  pkgs,
  ...
}: {
  imports = [
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"
  ];

  boot ={
    supportedFilesystems = lib.mkForce ["ext4" "vfat"];
    kernelPackages = pkgs.linuxKernel.packages.linux_rpi4;
    initrd.availableKernelModules = [ "xhci_pci" "usbhid" "usb_storage" ];
  };

  nixpkgs.overlays =  [
     # Workaround: https://github.com/NixOS/nixpkgs/issues/154163
      # modprobe: FATAL: Module sun4i-drm not found in directory
      (final: super: {
        makeModulesClosure = x:
          super.makeModulesClosure (x // {allowMissing = true;});
      })

      # Hotfix for https://github.com/NixOS/nixpkgs/pull/298001
      # TODO: Remove once in unstable
      (final: prev: {
        gnupg24 = prev.gnupg24.overrideAttrs(finalAttrs: previousAttrs: {
          configureFlags = builtins.filter (prev.lib.hasInfix "npth") previousAttrs.configureFlags ++ [
            "GPGRT_CONFIG=${prev.lib.getDev prev.libgpg-error}/bin/gpgrt-config"
          ];
        });
      })
  ];

  networking.hostName = hostname;
}
