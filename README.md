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

- Run Python gateway code: `readout_umg`
- Render Nix template expression: `nix-render-template template.nix < input.json > output.json`
- Generate VILLASndoe config from Gateway config: `villas-generate-gateway-config < gateway.json > villas-node.json`
- Start a full-fledged VM to test the configuration of VILLASnode `start-vm`

### Virtual Machine

Login credentials are: `villas` / `villas`

Then check the VILLASnode service and its config:

```shell
systemctl status villas-node

cat /boot/gateway.json
cat /boot/villas-config.json
```

You can exit the VM console by `Ctrl+A + X`.

## Development

```shell
pip install -e .
```

### Nix

```shell
nix develop
```

## License

- SPDX-FileCopyrightText: 2023 Felix Wege, EONERC-ACS, RWTH Aachen  University\
- SPDX-License-Identifier: Apache-2.0
