# SPDX-FileCopyrightText: 2024 Philipp Jungkamp, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{ agenix, ... }:
{ pkgs, lib, ... }:
let
  inherit (lib) getExe;
in
{
  imports = [ agenix.nixosModules.default ];

  age = {
    ageBin =
      with pkgs;
      getExe (writeShellApplication {
        name = "rage-with-plugins";
        runtimeInputs = [
          rage
          age-plugin-tpm
        ];
        text = ''exec rage "$@"'';
      });

    identityPaths = [ "/var/lib/keys/seguro.key" ];
  };
}
