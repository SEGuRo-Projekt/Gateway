# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{writeShellApplication, swtpm, system, inputs, ...}: let
  nixos-shell = inputs.nixos-shell.packages.${system}.nixos-shell;
in writeShellApplication {
  name = "start-vm";
  runtimeInputs = [nixos-shell swtpm];
  text = ''
    TPMSTATE=$(mktemp -d -t swtpm_XXXX)
    echo "TPM state is at: $TPMSTATE"

    # shellcheck disable=SC2064
    trap "trap - SIGTERM && kill -- -$$" SIGINT SIGTERM EXIT

    swtpm socket \
      --tpm2 \
      --tpmstate "dir=$TPMSTATE" \
      --ctrl "type=unixio,path=$TPMSTATE/swtpm-sock" &

    QEMU_OPTS="-chardev socket,id=chrtpm,path=$TPMSTATE/swtpm-sock -tpmdev emulator,id=tpm0,chardev=chrtpm -device tpm-tis,tpmdev=tpm0" \
    nixos-shell --flake .\#vm
  '';
}
