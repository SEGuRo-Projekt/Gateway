# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{pkgs, ...}: {
  environment.systemPackages = with pkgs; [ tpm2-tools tpm2-openssl openssl ];

  users.groups.tss.members = ["seguro"];

  security.tpm2 = {
    enable = true;
    abrmd.enable = true;
    pkcs11.enable = true;
    tctiEnvironment = {
      enable = true;
      interface = "tabrmd";
    };
  };
}
