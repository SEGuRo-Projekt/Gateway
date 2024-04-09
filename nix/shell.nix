# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
#
# A development shell to be used with `nix develop`
{
  mkShell,
  poetry,
  poetry2nix,
  reuse,
  python311Packages,
  pre-commit,
  nix-render-template,
  villas-generate-gateway-config,
  start-vm,
}:
mkShell {
  buildInputs = [
    (poetry2nix.mkPoetryEnv {
      projectDir = ../.;
      editablePackageSources = {
        seguro = ./seguro;
      };
      overrides = poetry2nix.defaultPoetryOverrides.extend (
        self: super: { cryptography = python311Packages.cryptography; }
      );
    })
  ];

  packages = [
    poetry
    reuse
    pre-commit

    nix-render-template
    villas-generate-gateway-config
    start-vm
  ];
}
