# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{ self, ... }:
{
  imports = with self.nixosModules; [ gateway-vm ];
}
