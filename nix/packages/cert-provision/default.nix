# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  writeShellApplication,
  curl,
  openssl,
  jq,
  ...
}:
writeShellApplication {
  name = "cert-provisioning";
  runtimeInputs = [
    curl
    openssl
    jq
  ];
  text = builtins.readFile ./renewal.sh;
}
