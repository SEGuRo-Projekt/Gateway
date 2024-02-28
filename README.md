# Gateway
Scripts for the measurement data transmission to the SEGuRo platform

## Installation

```shell
pip install .
```

### Nix

```shell
nix profile install \
  .\#villas-config-generator \
  .\#seguro-gateway

PATH=$PATH:~/.nix-profile/bin

villas-config-generator < config.json > config_villas.json

readout_umg801

# Or directly without installing:
nix run .\#villas-config-generator < config.json > config_villas.json

nix run .\#seguro-gateway
```

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
