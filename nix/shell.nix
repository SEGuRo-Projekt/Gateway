# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
#
# A development shell to be used with `nix develop`
{
  mkShell,
  python313,
  reuse,
  uv,
  callPackage,
  lib,
  pre-commit,
  nix-render-template,
  villas-generate-gateway-config,
  start-vm,
  inputs,
  ...
}:
let
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ../.;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  editableOverlay = workspace.mkEditablePyprojectOverlay {
    root = "$REPO_ROOT";
  };

  pythonSet =
    (callPackage inputs.pyproject-nix.build.packages {
      python = python313;
    }).overrideScope
      (
        lib.composeManyExtensions [
          inputs.pyproject-build-systems.overlays.wheel
          overlay
        ]
      );

  editablePythonSet = pythonSet.overrideScope editableOverlay;

  virtualenv = editablePythonSet.mkVirtualEnv "seguro-gateway-dev-env" workspace.deps.all;
in
mkShell {
  packages = [
    virtualenv
    uv
    reuse
    pre-commit

    nix-render-template
    villas-generate-gateway-config
    start-vm
  ];

  env = {
    UV_NO_SYNC = "1";
    UV_PYTHON = editablePythonSet.python.interpreter;
    UV_PYTHON_DOWNLOADS = "never";
  };

  shellHook = ''
    unset PYTHONPATH
    export REPO_ROOT=$(git rev-parse --show-toplevel)
  '';
}
