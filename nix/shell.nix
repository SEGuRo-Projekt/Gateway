# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
#
# A development shell to be used with `nix develop`
{
  mkShell,
  poetry,
  poetry2nix,
  reuse,
  python3Packages,
  pre-commit,
  nix-render-template,
  villas-generate-gateway-config,
  start-vm,
}:
let
  env = poetry2nix.mkPoetryEnv {
    projectDir = ../.;
    editablePackageSources = {
      seguro = ../seguro;
    };
    overrides = poetry2nix.defaultPoetryOverrides.extend (
      final: prev: { cryptography = python3Packages.cryptography; }
    );
  };

  scripts = poetry2nix.mkPoetryScriptsPackage { projectDir = ../.; };
in
mkShell {
  buildInputs = [ env ];

  packages = [
    poetry
    reuse
    pre-commit
    scripts

    nix-render-template
    villas-generate-gateway-config
    start-vm
  ];
}
