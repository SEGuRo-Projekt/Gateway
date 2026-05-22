# SPDX-FileCopyrightText: 2024 Philipp Jungkamp, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

inputs:
{
  config,
  ...
}:
{
  users.users = {
    seguro = {
      isNormalUser = true;
      extraGroups = [ "wheel" ];
      uid = 2001;

      initialPassword = "seguro";
    };

    root.openssh.authorizedKeys.keys = config.users.users.seguro.openssh.authorizedKeys.keys;
  };

  nix.settings.trusted-users = [
    "root"
    "seguro"
  ];
}
