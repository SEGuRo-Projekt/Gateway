# Gateway
Scripts for the measurement data transmission to the SEGuRo platform

## Installation

```shell
pip install .
```

## Nix

### Enter development shell

Either by running:

```shell
nix develop
```

or by installing [direnv](https://direnv.net/) and running:

```shell
direnv allow
```

Inside the development shell you can directly work on the Python code or use the following commands:

- Run Python gateway code: `opcua-readout`
- Render Nix template expression: `nix-render-template template.nix < input.json > output.json`
- Generate VILLASndoe config from Gateway config: `villas-generate-gateway-config < gateway.json > villas-node.json`
- Start a full-fledged VM to test the configuration of VILLASnode `start-vm`

### Virtual machine

Start the VM by running: `start-vm`.

Then check the VILLASnode service and its config:

```shell
systemctl status villas-node

cat /boot/firmware/gateway.json
cat /boot/firmware/villas-config.json
```

You can exit the VM console by `Ctrl+A + X`.

### Build Raspberry Pi SD-card image

Build a SD-card image by running:

```shell
nix build .#nixosConfigurations.rpi-1.config.system.build.sdImage
```

or short

```shell
nix build .
```

This will place the generated SD-card image under `./result/sd-image/`.

You can use `dd` to copy this image to a real SD-card:

```shell
zstd -d ./result/sd-image/*.img.zst | dd of=/dev/sdX bs=4k
```

## Development

```shell
pip install -e .
```

## License

- SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen  University
- SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
- SPDX-License-Identifier: Apache-2.0
