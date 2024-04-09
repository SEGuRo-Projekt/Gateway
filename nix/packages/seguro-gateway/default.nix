# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
#
# A Python / Poetry application used for getting data from
# Janitza UMG measurement devices via OPC-UA.
# This application is used by VILLASnode exec-node type.
{poetry2nix, python311Packages, ...}: poetry2nix.mkPoetryApplication {
  projectDir = ../../../.;

   overrides = poetry2nix.defaultPoetryOverrides.extend
    (self: super: {
      cryptography = python311Packages.cryptography;
    });
}
