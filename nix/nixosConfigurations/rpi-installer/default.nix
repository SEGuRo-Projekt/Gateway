# SPDX-FileCopyrightText: 2024 Philipp Jungkamp, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{
  system = "aarch64-linux";
  modules = [
    ./configuration.nix
    ./hardware-configuration.nix
  ];
}
