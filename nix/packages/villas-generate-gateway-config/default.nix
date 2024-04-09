# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
#
# A simple shell script which uses nix-render-template
# to transform a SEGuRo Gateway JSON configuration file into
# a VILLASnode JSON configuration file.
#
# The SEGuRo Gateway JSON configuration file is read from stdin.
# The VILLASnode JSON configuration file is written to stdout.
{ writeShellApplication, nix-render-template, ... }:
let
  seguroGatewayConfigTemplate = ./seguro-gateway-config.nix;
in
writeShellApplication {
  name = "villas-generate-gateway-config";
  runtimeInputs = [ nix-render-template ];

  text = "nix-render-template ${seguroGatewayConfigTemplate}";
}
