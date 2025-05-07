# SPDX-FileCopyrightText: 2025 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0

{
  writeShellApplication,
  curl,
  openssl,
  ...
}:
writeShellApplication {
  name = "cert-renewal";
  runtimeInputs = [
    curl
    openssl
  ];
  text = builtins.readFile ./renewal.sh;
}
