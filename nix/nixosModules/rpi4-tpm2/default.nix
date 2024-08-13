# SPDX-FileCopyrightText: 2024 Steffen Vogel, OPAL-RT Germany GmbH
# SPDX-License-Identifier: Apache-2.0
{ pkgs, self, ... }:
{
  imports = with self.nixosModules; [
    tpm
  ];

  hardware = {
    deviceTree.overlays = [
      {
        name = "tpm-slb9670-overlay";
        dtsText = ''
          /*
           * Device Tree overlay for the Infineon SLB9670 Trusted Platform Module add-on
           * boards, which can be used as a secure key storage and hwrng.
           * available as "Iridium SLB9670" by Infineon and "LetsTrust TPM" by pi3g.
           */

           /dts-v1/;
           /plugin/;

           / {
             compatible = "brcm,bcm2835";

             fragment@0 {
               target = <&spi0>;
               __overlay__ {
                 status = "okay";
               };
             };

             fragment@1 {
               target = <&spidev1>;
               __overlay__ {
                 status = "disabled";
               };
             };

             fragment@2 {
               target = <&spi0>;
               __overlay__ {
                 /* needed to avoid dtc warning */
                 #address-cells = <1>;
                 #size-cells = <0>;
                 slb9670: slb9670@1 {
                   compatible = "infineon,slb9670";
                   reg = <1>;	/* CE1 */
                   #address-cells = <1>;
                   #size-cells = <0>;
                   spi-max-frequency = <32000000>;
                   status = "okay";
                 };

               };
             };
           };
        '';
      }
    ];
  };
}
