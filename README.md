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
nix build .#nixosConfigurations.gateway-rpi.config.system.build.sdImage
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

## Gateway Customization
The base gateway configuration in this repository is exposed as a NixOS
module (`nixosModules.gateway-rpi`). Use case specific deployments can reference it from their own top-level flake and layer use-case specific configuration on top, rather than forking this repo directly.

A typical use case flake pins this repository as an input, then defines its
own `nixosConfigurations` that import the base module alongside custom
options, additional services, and any nixpkgs overlays needed:

```nix
{
  description = "Use case specific configurations of the SEGuRo Gateway";

  inputs.seguro-gateway{
    url = "github:SEGuRo-Projekt/Gateway/nix-updates";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flake-utils.follows = "flake-utils";
      };
  }

  outputs = { self, nixpkgs, seguro-gateway, ... }: {
    nixosConfigurations.my-gateway = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        seguro-gateway.nixosModules.gateway-rpi
        {
          nixpkgs.overlays = [ (import ./overlays/my-custom-packages.nix) ];
          services.gateway.autoUpgrade.enable = true;
          # additional use case options and services
        }
        ./configuration.nix
      ];
    };
  };
}
```

This keeps user specific secrets, network settings, and service selection
out of the shared repository, while still tracking upstream improvements to
the base gateway module as this repository evolves.

For details on customizing Gateway services, see [the docs.](docs/service-customization.md)

## Acknowlegements

We are grateful for the financial support of the [BMWE (Federal Ministry of Economic Affairs and Energy)](https://www.bundeswirtschaftsministerium.de/Navigation/EN/Home/home.html), funding reference [03El6085](https://www.enargus.de/pub/bscw.cgi/?op=enargus.eps2&q=%2201249617/1%22).

## License

- SPDX-FileCopyrightText: 2026 Felix Wege, EONERC-ACS, RWTH Aachen  University
- SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
- SPDX-License-Identifier: Apache-2.0
