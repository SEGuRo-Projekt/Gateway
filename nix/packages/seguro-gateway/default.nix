# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
#
# A Python / uv application used for getting data from
# Janitza UMG measurement devices via OPC-UA.
# This application is used by VILLASnode exec-node type.
{
  python313,
  callPackage,
  lib,
  inputs,
  ...
}:
let
  workspace = inputs.uv2nix.lib.workspace.loadWorkspace {
    workspaceRoot = ../../../.;
  };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
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
in
pythonSet.mkVirtualEnv "seguro-gateway-env" workspace.deps.default
